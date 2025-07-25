# == Schema Information
#
# Table name: communication_website_agenda_period_days
#
#  id                       :uuid             not null, primary key
#  date                     :date
#  value                    :integer          uniquely indexed => [university_id, communication_website_id, year_id, month_id]
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  communication_website_id :uuid             not null, indexed, uniquely indexed => [university_id, year_id, month_id, value]
#  month_id                 :uuid             not null, indexed, uniquely indexed => [university_id, communication_website_id, year_id, value]
#  university_id            :uuid             not null, uniquely indexed => [communication_website_id, year_id, month_id, value]
#  year_id                  :uuid             not null, indexed, uniquely indexed => [university_id, communication_website_id, month_id, value]
#
# Indexes
#
#  idx_on_communication_website_id_54db819007                  (communication_website_id)
#  index_communication_website_agenda_period_days_on_month_id  (month_id)
#  index_communication_website_agenda_period_days_on_year_id   (year_id)
#  index_communication_website_agenda_period_days_unique       (university_id,communication_website_id,year_id,month_id,value) UNIQUE
#
# Foreign Keys
#
#  fk_rails_3b10063259  (month_id => communication_website_agenda_period_months.id)
#  fk_rails_b73faa1b88  (communication_website_id => communication_websites.id)
#  fk_rails_c266025ea4  (university_id => universities.id)
#  fk_rails_caaa93280f  (year_id => communication_website_agenda_period_years.id)
#
class Communication::Website::Agenda::Period::Day < ApplicationRecord
  include AsDirectObject
  include Communication::Website::Agenda::Period::Base
  include GeneratesGitFiles
  include Localizable
  include WithUniversity

  belongs_to :year
  belongs_to :month

  def next
    Communication::Website::Agenda::Period::Day.find_by(
      university: university,
      website: website,
      year: year,
      month: month,
      value: value + 1
    )
  end

  def denormalize_localizations_events_count
    localizations.find_each(&:denormalize_events_count)
  end
end
