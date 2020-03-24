require_dependency 'issue'

module ExtendedWatchersIssuePatch

    def self.included(base)
        base.send(:include, InstanceMethods)
        base.extend ClassMethods
        base.class_eval do
            unloadable

            #alias_method_chain :visible?, :extwatch
            alias_method :visible_without_extwatch?, :visible?
            alias_method :visible?, :visible_with_extwatch?

            #alias_method_chain :attributes_editable?, :extwatch
            alias_method :attributes_editable_without_extwatch?, :attributes_editable?
            alias_method :attributes_editable?, :attributes_editable_with_extwatch?

            class << self
                #alias_method_chain :visible_condition, :extwatch
                alias_method :visible_condition_without_extwatch, :visible_condition
                alias_method :visible_condition, :visible_condition_with_extwatch
            end
        end
    end

    module ClassMethods
      def visible_condition_with_extwatch(user, options={})
        watched_issues = []

        if user.logged?
          user_ids = [user.id] + user.groups.map(&:id).compact
          watched_issues = Issue.watched_by(user).joins(:project => :enabled_modules).where("#{EnabledModule.table_name}.name = 'issue_tracking'").map(&:id)
        end

        prj_clause = options.nil? || options[:project].nil? ? nil : " #{Project.table_name}.id = #{options[:project].id}"
        prj_clause << " OR (#{Project.table_name}.lft > #{options[:project].lft} AND #{Project.table_name}.rgt < #{options[:project].rgt})" if !options.nil? and !options[:project].nil? and options[:with_subprojects]
        watched_group_issues_clause = ""
        watched_group_issues_clause <<  " OR #{table_name}.id IN (#{watched_issues.join(',')})" <<
            (prj_clause.nil? ? "" : " AND ( #{prj_clause} )") unless watched_issues.empty?

        "( " + visible_condition_without_extwatch(user, options) + "#{watched_group_issues_clause}) "
      end
    end

    module InstanceMethods
        def visible_with_extwatch?(usr=nil)
          visible = visible_without_extwatch?(usr)
          logger.debug "visible_without_extwatch #{visible}"

          return true if visible

          if (usr || User.current).logged?
            visible =  self.watched_by?(usr || User.current)
          end

          logger.debug "visible_with_extwatch #{visible}"
          visible
        end

        def attributes_editable_with_extwatch?(user=User.current)
          if self.watched_by?(user) && self.assigned_to_id != user.id && self.author_id != user.id
            return true if user.admin?
	    return true if user_tracker_permission?(user, :edit_issues)

            roles = user.roles_for_project(project).select {|r| r.has_permission?(:edit_watched_issues)}
            roles.any? {|r| r.permissions_all_trackers?(:edit_watched_issues) || r.permissions_tracker_ids?(:edit_watched_issues, self.tracker_id)}
          else
            attributes_editable_without_extwatch?(user)
          end
        end
    end
end
