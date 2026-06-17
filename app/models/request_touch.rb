class RequestTouch < ApplicationRecord
  self.table_name = "T_RequestTouches"

  validates :touch_type, presence: true

  enum touch_type: {
    view: 0,
    shared: 2,
    accessed_online: 3,
    created: 101,
    status_change_pending: 20,
    status_change_accepted: 21,
    status_change_denied: 22,
    workflow_triggered: 8
  }

  scope :by_type, ->(type) { where(touch_type: type) }
end
