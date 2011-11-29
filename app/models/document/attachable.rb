module Document::Attachable
  extend ActiveSupport::Concern

  class Trait < Document::Traits::Trait
    def process_associations_after_save(document)
      @document.attachments.each do |a|
        document.document_attachments.create(attachment_id: a.id)
      end
    end
  end

  included do
    has_many :document_attachments, foreign_key: "document_id"
    has_many :attachments, through: :document_attachments

    accepts_nested_attributes_for :document_attachments, allow_destroy: true
    accepts_nested_attributes_for :attachments

    add_trait Trait
  end

  def allows_attachments?
    true
  end
end