# == Schema Information
#
# Table name: communication_blocks
#
#  id                       :uuid             not null, primary key
#  about_type               :string           indexed => [about_id]
#  data                     :jsonb
#  html_class               :string
#  migration_identifier     :string
#  position                 :integer          not null
#  published                :boolean          default(TRUE)
#  template_kind            :integer          default(NULL), not null, indexed => [university_id]
#  title                    :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  about_id                 :uuid             indexed => [about_type]
#  communication_website_id :uuid             indexed
#  university_id            :uuid             not null, indexed => [template_kind]
#
# Indexes
#
#  index_communication_blocks_on_communication_website_id         (communication_website_id)
#  index_communication_blocks_on_university_id_and_template_kind  (university_id,template_kind)
#  index_communication_website_blocks_on_about                    (about_type,about_id)
#
# Foreign Keys
#
#  fk_rails_18291ef65f  (university_id => universities.id)
#  fk_rails_80e5625874  (communication_website_id => communication_websites.id)
#
class Communication::Block < ApplicationRecord
  BLOCK_COPY_COOKIE = 'osuny-content-editor-block-copy'
  CATEGORIES = {
    basic: [:title, :chapter, :image, :video, :sound, :datatable],
    storytelling: [:key_figures, :features, :gallery, :call_to_action, :testimonials, :timeline],
    references: [:pages, :posts, :persons, :organizations, :agenda, :exhibitions, :programs, :locations, :projects, :papers, :volumes, :jobs, :categories],
    utilities: [:files, :definitions, :contact, :links, :license, :embed]
  }

  include AsIndirectObject
  include Filterable
  include Orderable
  include WithAccessibility
  include WithHeadingRanks
  include WithHtmlClass
  include WithMediaLibrary
  include WithTemplate
  include WithOpenApi # Must be included after WithTemplate to load template_kinds
  include WithUniversity
  include Sanitizable

  belongs_to  :about, polymorphic: true
  belongs_to  :communication_website,
              class_name: "Communication::Website",
              optional: true
  alias       :website :communication_website

  before_validation :set_university_and_website_from_about, on: :create
  before_validation :execute_template_before_validation

  # We do not use the :touch option of the belongs_to association
  # because we do not want to touch the about when destroying the block.
  after_save :touch_about#, :touch_targets # FIXME

  scope :published, -> { where(published: true) }
  scope :for_template_kind, -> (template_kind, language = nil) { where(template_kind: template_kind) }
  scope :for_about_type, -> (about_type, language = nil) { where(about_type: about_type) }
  scope :for_university, -> (university, language = nil) { where(university: university) }

  # When we set data from json, we pass it to the template.
  # The json we save is first sanitized and prepared by the template.
  def data=(value)
    template.data = value
    super template.data
  end

  # Template data is clean and sanitized, and initialized with json
  def data
    template.data
  end

  def dependencies
    template.dependencies
  end

  def references
    [about]
  end

  def language
    return @language if defined?(@language)
    return unless about.respond_to?(:language)
    @language ||= about.language
  end

  def duplicate
    block = self.dup
    block.save
    block
  end

  def paste(about)
    block = self.dup
    block.about = about
    block.save
    block
  end

  def localize_for!(new_localization)
    localized_block = self.dup
    localized_block.about = new_localization
    localized_block.save
  end

  def empty?
    template.empty?
  end

  def full_text
    "#{title} #{template.full_text}"
  end

  def slug
    title.blank? ? '' : "#{title.parameterize}"
  end

  def to_s
    title.blank?  ? "#{Communication::Block.model_name.human} #{position}"
                  : "#{title}"
  end

  protected

  def last_ordered_element
    about.blocks.ordered.last
  end

  def set_university_and_website_from_about
    # about always have an university_id but can have no communication_website_id
    self.university_id = about.university_id
    self.communication_website_id = about.try(:communication_website_id)
  end

  def execute_template_before_validation
    template.before_validation
  end

  def check_accessibility
    accessibility_merge template
  end

  def touch_about
    about.touch
  end

  def connect_to_websites
    # We do nothing as the about will perform it
  end

  # Invalidation des caches des personnes pour les backlinks
  # if a block changed we need to touch the old targets (for example persons previously connected), and the new connected ones
  # FIXME
  def touch_targets
    if persons? || organizations?
      dependencies.each(&:touch)
      # TODO: @arnaud help!
      # I need to touch the old dependencies
      # Ideally we should only touch the diff between old and new dependencies
    end
  end
end
