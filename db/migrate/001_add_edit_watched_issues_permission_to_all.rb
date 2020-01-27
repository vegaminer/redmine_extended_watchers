class AddEditWatchedIssuesPermissionToAll < ActiveRecord::Migration[4.2]
  def up
    execute %Q(
      UPDATE roles
      SET permissions = CONCAT(permissions, '- :edit_watched_issues\n')
    )
  end
end
