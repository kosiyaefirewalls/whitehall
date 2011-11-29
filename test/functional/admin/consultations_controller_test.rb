require 'test_helper'

class Admin::ConsultationsControllerTest < ActionController::TestCase

  setup do
    @user = login_as :policy_writer
  end

  test_controller_is_a Admin::BaseController

  test 'new displays consultation form' do
    get :new

    assert_select "form[action='#{admin_consultations_path}']" do
      assert_select "input[name='document[title]'][type='text']"
      assert_select "textarea[name='document[body]']"
      assert_select "input[name='document[attachments_attributes][0][file]'][type='file']"
      assert_select "select[name*='document[opening_on']", count: 3
      assert_select "select[name*='document[closing_on']", count: 3
      assert_select "select[name*='document[organisation_ids]']"
      assert_select "select[name*='document[ministerial_role_ids]']"
      assert_select "input[type='submit']"
    end
  end

  test 'creating creates a new consultation' do
    first_org = create(:organisation)
    second_org = create(:organisation)
    first_minister = create(:ministerial_role)
    second_minister = create(:ministerial_role)
    attributes = attributes_for(:consultation)

    post :create, document: attributes.merge(
      organisation_ids: [first_org.id, second_org.id],
      ministerial_role_ids: [first_minister.id, second_minister.id]
    )

    consultation = Consultation.last
    assert_equal attributes[:title], consultation.title
    assert_equal attributes[:body], consultation.body
    assert_equal attributes[:opening_on].to_date, consultation.opening_on
    assert_equal attributes[:closing_on].to_date, consultation.closing_on
    assert_equal [first_org, second_org], consultation.organisations
    assert_equal [first_minister, second_minister], consultation.ministerial_roles
  end

  test 'creating a consultation should attach file' do
    attributes = attributes_for(:consultation)
    greenpaper_pdf = fixture_file_upload('greenpaper.pdf')
    attributes[:attachments_attributes] = { "0" => { file: greenpaper_pdf } }

    post :create, document: attributes

    assert consultation = Consultation.last
    assert_equal 1, consultation.attachments.length
    attachment = consultation.attachments.first
    assert_equal "greenpaper.pdf", attachment.carrierwave_file
  end

  test 'creating takes the writer to the consultation page' do
    post :create, document: attributes_for(:consultation)

    assert_redirected_to admin_consultation_path(Consultation.last)
    assert_equal 'The document has been saved', flash[:notice]
  end

  test 'show displays consultation opening date' do
    consultation = create(:consultation, opening_on: Date.new(2011, 10, 10))
    get :show, id: consultation
    assert_select '.opening_on', text: 'Opened on October 10th, 2011'
  end

  test 'creating with invalid data should leave the writer in the consultation editor' do
    attributes = attributes_for(:consultation)
    post :create, document: attributes.merge(title: '')

    assert_equal attributes[:body], assigns(:document).body, "the valid data should not have been lost"
    assert_template "documents/new"
  end

  test 'creating with invalid data should set an alert in the flash' do
    attributes = attributes_for(:consultation)
    post :create, document: attributes.merge(title: '')

    assert_equal 'There are some problems with the document', flash.now[:alert]
  end

  test "creating a consultation with invalid data should still allow attachment to be selected for upload" do
    post :create, document: attributes_for(:consultation, title: "")

    assert_select "form#document_new" do
      assert_select "input[name='document[attachments_attributes][0][file]'][type='file']"
    end
  end

  test "creating a consultation with invalid data should only allow a single attachment to be selected for upload" do
    greenpaper_pdf = fixture_file_upload('greenpaper.pdf')

    post :create, document: attributes_for(:consultation,
      title: "",
      attachments_attributes: { "0" => { file: greenpaper_pdf } }
    )

    assert_select "form#document_new" do
      assert_select "input[name*='document[attachments_attributes]'][type='file']", count: 1
    end
  end

  test 'show displays consultation closing date' do
    consultation = create(:consultation, opening_on: Date.new(2010, 01, 01), closing_on: Date.new(2011, 01, 01))
    get :show, id: consultation
    assert_select '.closing_on', text: 'Closed on January 1st, 2011'
  end

  test 'show displays consultation attachment' do
    consultation = create(:consultation, attachments: [create(:attachment)])
    get :show, id: consultation
    assert_select '.attachment a', text: consultation.attachments.first.filename
  end

  test 'show displays related policies' do
    policy = create(:policy)
    consultation = create(:consultation, documents_related_to: [policy])
    get :show, id: consultation
    assert_select_object policy
  end

  test 'edit displays consultation form' do
    consultation = create(:consultation)

    get :edit, id: consultation

    assert_select "form[action='#{admin_consultation_path(consultation)}']" do
      assert_select "input[name='document[title]'][type='text']"
      assert_select "textarea[name='document[body]']"
      assert_select "input[name='document[attachments_attributes][0][file]'][type='file']"
      assert_select "select[name*='document[opening_on']", count: 3
      assert_select "select[name*='document[closing_on']", count: 3
      assert_select "select[name*='document[organisation_ids]']"
      assert_select "select[name*='document[ministerial_role_ids]']"
      assert_select "input[type='submit']"
    end
  end

  test 'updating should save modified policy attributes' do
    first_org = create(:organisation)
    second_org = create(:organisation)
    first_minister = create(:ministerial_role)
    second_minister = create(:ministerial_role)

    consultation = create(:consultation, organisations: [first_org], ministerial_roles: [first_minister])

    put :update, id: consultation, document: {
      title: "new-title",
      body: "new-body",
      opening_on: 1.day.ago,
      closing_on: 50.days.from_now,
      organisation_ids: [second_org.id],
      ministerial_role_ids: [second_minister.id]
    }

    consultation.reload
    assert_equal "new-title", consultation.title
    assert_equal "new-body", consultation.body
    assert_equal 1.day.ago.to_date, consultation.opening_on
    assert_equal 50.days.from_now.to_date, consultation.closing_on
    assert_equal [second_org], consultation.organisations
    assert_equal [second_minister], consultation.ministerial_roles
  end

  test 'updating should remove all organisation and ministerial roles if none in params' do
    org = create(:organisation)
    minister = create(:ministerial_role)

    consultation = create(:consultation, organisations: [org], ministerial_roles: [minister])

    put :update, id: consultation, document: {}

    consultation.reload
    assert_equal [], consultation.organisations
    assert_equal [], consultation.ministerial_roles
  end

  test "updating a consultation with invalid data should still allow attachment to be selected for upload" do
    consultation = create(:consultation)
    put :update, id: consultation, document: consultation.attributes.merge(title: "")

    assert_select "form#document_edit" do
      assert_select "input[name='document[attachments_attributes][0][file]'][type='file']"
    end
  end

  test "updating a consultation with invalid data should only allow a single attachment to be selected for upload" do
    consultation = create(:consultation)
    greenpaper_pdf = fixture_file_upload('greenpaper.pdf')

    put :update, id: consultation, document: attributes_for(:consultation,
      title: "",
      attachments_attributes: { "0" => { file: greenpaper_pdf } }
    )

    assert_select "form#document_edit" do
      assert_select "input[name*='document[attachments_attributes]'][type='file']", count: 1
    end
  end

  test 'updating a stale consultation should render edit page with conflicting consultation' do
    consultation = create(:draft_consultation, organisations: [build(:organisation)], ministerial_roles: [build(:ministerial_role)])
    lock_version = consultation.lock_version
    consultation.touch

    put :update, id: consultation, document: consultation.attributes.merge(
      lock_version: lock_version
    )

    assert_template 'edit'
    conflicting_consultation = consultation.reload
    assert_equal conflicting_consultation, assigns[:conflicting_document]
    assert_equal conflicting_consultation.lock_version, assigns[:document].lock_version
    assert_equal %{This document has been saved since you opened it}, flash[:alert]
  end

  test "updating a stale consultation should still allow attachment to be selected for upload" do
    consultation = create(:draft_consultation)
    lock_version = consultation.lock_version
    consultation.touch

    put :update, id: consultation, document: consultation.attributes.merge(lock_version: lock_version)

    assert_select "form#document_edit" do
      assert_select "input[name='document[attachments_attributes][0][file]'][type='file']"
    end
  end

  test "updating a stale consultation should only allow a single attachment to be selected for upload" do
    consultation = create(:consultation)
    greenpaper_pdf = fixture_file_upload('greenpaper.pdf')

    consultation = create(:draft_consultation)
    lock_version = consultation.lock_version
    consultation.touch

    put :update, id: consultation, document: consultation.attributes.merge(
      lock_version: lock_version,
      attachments_attributes: { "0" => { file: greenpaper_pdf } }
    )

    assert_select "form#document_edit" do
      assert_select "input[name*='document[attachments_attributes]'][type='file']", count: 1
    end
  end

  test 'updating should allow removal of attachments' do
    attachment_1 = create(:attachment)
    attachment_2 = create(:attachment)
    attributes = attributes_for(:consultation)
    consultation = create(:consultation, attributes.merge(attachments: [attachment_1, attachment_2]))
    document_attachments_attributes = consultation.document_attachments.inject({}) do |h, da|
      h[da.id] = da.attributes.merge("_destroy" => (da.attachment == attachment_1 ? "1" : "0"))
      h
    end
    put :update, id: consultation, document: attributes.merge(document_attachments_attributes: document_attachments_attributes)

    consultation.reload
    assert_equal [attachment_2], consultation.attachments
  end

  should_display_attachments_for :consultation

  should_be_rejectable :consultation
  should_be_force_publishable :consultation
  should_be_able_to_delete_a_document :consultation

  should_link_to_public_version_when_published :consultation
  should_not_link_to_public_version_when_not_published :consultation
end