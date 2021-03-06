class Topic < ActiveRecord::Base
  belongs_to :user
  belongs_to :meeting
  has_many :voters
  has_many :volunteers
  has_many :kudos

  has_many :users, :through => :kudos
  
  validates :title, presence: true
  validates :description, presence: true

  attr_accessible :description, :meeting_id, :state, :title

  state_machine initial: :open do
    state :open
    state :selected
    state :closed

    event :select do
      transition to: :selected, from: [:open]
    end

    event :close do
      transition to: :closed, from: [:selected]
    end
  end

  def self.open_by_votes
    select('topics.*, COUNT(voters.id) AS votes')
    .joins(:voters)
    .with_state(:open)
    .group('topics.id')
    .order('votes DESC')
  end

  def self.by_most_recent
    order('created_at DESC')
  end

  def give_points_to(presenter)
    [
      { name: user.name, points: user.earn_points!(suggestion_points) },
      { name: presenter.name, points: presenter.earn_points!(presenter_points)}
    ]
  end

  def votes
    voters.count
  end

  alias :points :votes

  def mark_as_selected!(meeting)
    self.update_attribute(:meeting_id, meeting.id)
    select!
  end

  def suggestion_points
    points / 4
  end

  def presenter_points
    5 + (points - suggestion_points) + kudos.count
  end

  def give_kudo_as(user)
    return false unless can_add_kudo?(user)
    Kudo.create!(topic: self, user: user)
  rescue ActiveRecord::RecordInvalid
    add_kudo_error("we've reported this to Alex Peachey, cheating asshole.")
  end

  def can_add_kudo?(user)
    return add_kudo_error('too late, asshole.') unless meeting.open?
    return true unless user_ids.include?(user.id)
    add_kudo_error("we've reported this to Alex Peachey, cheating asshole.")
  end

private

  def add_kudo_error(message)
    errors.add :kudos, message
    false
  end

end
