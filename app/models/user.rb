# == Schema Information
#
# Table name: users
#
#  id                     :bigint(8)        not null, primary key
#  roles                  :string           default([]), is an Array
#  skills                 :text             default([]), is an Array
#  first_name             :string           not null
#  last_name              :string           not null
#  company_name           :string
#  address_1              :string
#  address_2              :string
#  city                   :string
#  region                 :string
#  postal_code            :string
#  country                :string
#  us_resident            :boolean          default(FALSE)
#  api_access             :boolean          default(FALSE), not null
#  api_key                :string
#  bio                    :text
#  website_url            :string
#  github_username        :string
#  twitter_username       :string
#  linkedin_username      :string
#  paypal_email           :string
#  email                  :string           not null
#  encrypted_password     :string           not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :inet
#  last_sign_in_ip        :inet
#  confirmation_token     :string
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  unconfirmed_email      :string
#  failed_attempts        :integer          default(0), not null
#  unlock_token           :string
#  locked_at              :datetime
#  invitation_token       :string
#  invitation_created_at  :datetime
#  invitation_sent_at     :datetime
#  invitation_accepted_at :datetime
#  invitation_limit       :integer
#  invited_by_type        :string
#  invited_by_id          :bigint(8)
#  invitations_count      :integer          default(0)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#

class User < ApplicationRecord
  # extends ...................................................................

  # includes ..................................................................
  include Users::Presentable
  include Eventable
  include Imageable
  include Taggable

  # relationships .............................................................
  has_many :campaigns
  has_many :creatives
  has_many :impressions_as_advertiser, class_name: "Impression", foreign_key: "advertiser_id"
  has_many :properties

  # validations ...............................................................
  validates :first_name, presence: true
  validates :last_name, presence: true

  # callbacks .................................................................
  before_save :ensure_roles

  # scopes ....................................................................
  scope :administrators, -> { with_all_roles ENUMS::USER_ROLES::ADMINISTRATOR }
  scope :advertisers, -> { with_all_roles ENUMS::USER_ROLES::ADVERTISER }
  scope :publishers, -> { with_all_roles ENUMS::USER_ROLES::PUBLISHER }
  scope :search_company, ->(value) { value.blank? ? all : search_column(:company_name, value) }
  scope :search_email, ->(value) { value.blank? ? all : search_column(:email, value) }
  scope :search_name, ->(value) { value.blank? ? all : search_column(:first_name, value).or(search_column(:last_name, value)) }
  scope :search_roles, ->(*values) { values.blank? ? all : with_any_roles(*values) }

  # Scopes and helpers provied by tag_columns
  # SEE: https://github.com/hopsoft/tag_columns
  #
  # - with_roles
  # - without_roles
  # - with_any_roles
  # - without_any_roles
  # - with_all_roles
  # - without_all_roles
  #
  # Examples
  #
  #   irb>User.with_roles(:admin)
  #   irb>User.without_any_roles(:advertiser, :publisher)

  # Scopes and helpers provied by devise_invitable
  # SEE: https://github.com/scambra/devise_invitable
  #
  # - invitation_accepted
  # - invitation_not_accepted
  # - created_by_invite
  # - created_by_invite?        # Verify wheather a user is created by invitation, irrespective to invitation status
  # - invited_to_sign_up?       # Verifies whether a user has been invited or not
  # - accepting_invitation?     # Returns true if accept_invitation! was called
  # - invitation_accepted?      # Verifies whether a user accepted an invitation (false when user is accepting it)
  # - accepted_or_not_invited?  # Verifies whether a user has accepted an invitation (false when user is accepting it), or was never invited
  #
  # Examples
  #
  #   irb>User.invitation_accepted
  #   irb>User.invitation_not_accepted
  #   irb>User.created_by_invite

  # additional config (i.e. accepts_nested_attribute_for etc...) ..............
  begin
    tag_columns :roles
    tag_columns :skills
  rescue
    # rescue required for initial migration due to devise
    ActiveRecord::NoDatabaseError
  end
  devise(
    :confirmable,
    :database_authenticatable,
    :invitable,
    :lockable,
    :recoverable,
    :rememberable,
    :timeoutable,
    :trackable,
    :validatable,
  )
  has_one_attached :avatar
  acts_as_commentable
  has_paper_trail on: %i[create update destroy], only: %i[
    api_access
    api_key
    company_name
    email
    first_name
    last_name
    roles
  ]

  # class methods .............................................................
  class << self
    def find_version_author(version)
      return unless version.terminator
      find(version.terminator)
    end
  end

  # public instance methods ...................................................

  def administrator?
    roles.include? ENUMS::USER_ROLES["administrator"]
  end

  def advertiser?
    roles.include? ENUMS::USER_ROLES["advertiser"]
  end

  def publisher?
    roles.include? ENUMS::USER_ROLES["publisher"]
  end

  def total_distributions
    250.00
  end

  def revenue_rate
    0.6
  end

  def small_images(wrapped = false)
    list = images.search_metadata_format(ENUMS::IMAGE_FORMATS::SMALL)
    return list unless wrapped
    list.map { |i| Image.new(i) }
  end

  def large_images(wrapped = false)
    list = images.search_metadata_format(ENUMS::IMAGE_FORMATS::LARGE)
    return list unless wrapped
    list.map { |i| Image.new(i) }
  end

  def wide_images(wrapped = false)
    list = images.search_metadata_format(ENUMS::IMAGE_FORMATS::WIDE)
    return list unless wrapped
    list.map { |i| Image.new(i) }
  end

  def to_s
    full_name
  end

  # protected instance methods ................................................

  # private instance methods ..................................................
  private

  def ensure_roles
    self.roles = roles & ENUMS::USER_ROLES.values
  end
end
