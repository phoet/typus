require "test_helper"

=begin

  What's being tested here?

    - Sessions

=end

class Admin::SessionControllerTest < ActionController::TestCase

  test 'verify_remote_ip' do
    Typus.stubs(:ip_whitelist).returns(%w(10.0.0.5))
    get :new
    assert_equal 'IP not in our whitelist.', @response.body

    request.stubs(:local?).returns(true)

    Typus.ip_whitelist = %w(10.0.0.5)
    get :new
    assert_response :success

    Typus.ip_whitelist = []
    get :new
    assert_response :success
  end

  test 'get new redirects to new_admin_account_path when no admin users' do
    TypusUser.delete_all
    get :new
    assert_response :redirect
    assert_redirected_to new_admin_account_path
  end

  test 'get new always sets locale to Typus.default_locale' do
    I18n.locale = :es
    get :new
    assert_equal :en, I18n.locale
  end

  test 'new is rendered when there are users' do
    Typus.stubs(:mailer_sender).returns(nil)

    get :new
    assert_response :success

    # render new and verify title and header
    assert_select 'title', 'Please sign in &middot; Typus'
    assert_select 'h2', 'Please sign in'

    # render session layout
    assert_template 'new'
    assert_template 'layouts/admin/session'

    # verify_typus_sign_in_layout_does_not_include_recover_password_link
    assert !response.body.include?('Recover password')
  end

  test 'new includes recover_password_link when mailer_sender is set' do
    Typus.stubs(:mailer_sender).returns('john@example.com')
    get :new
    assert response.body.include?('Recover password')
  end

  test 'create should not create session for invalid users' do
    post :create, { typus_user: { email: 'john@example.com', password: 'XXXXXXXX' } }
    assert_response :redirect
    assert_redirected_to new_admin_session_path
  end

  test 'create should not create session for a disabled user' do
    typus_user = typus_users(:admin)
    typus_user.update_column(:status, false)

    post :create, { typus_user: { email: typus_user.email, password: '12345678' } }

    assert_nil request.session[:typus_user_id]
    assert_response :redirect
    assert_redirected_to new_admin_session_path
  end

  test 'create should create session for an enabled user' do
    typus_user = typus_users(:admin)
    post :create, { typus_user: { email: typus_user.email, password: '12345678' } }

    assert_equal typus_user.id, request.session[:typus_user_id]
    assert_response :redirect
    assert_redirected_to admin_dashboard_index_path
  end

  test 'destroy' do
    admin_sign_in
    assert request.session[:typus_user_id]
    delete :destroy

    assert_nil request.session[:typus_user_id]
    assert_response :redirect
    assert_redirected_to new_admin_session_path
    assert flash.empty?
  end

end
