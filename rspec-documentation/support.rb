class UsersController < ActiveElement::ApplicationController
  def initialize(*args, &block)
    append_view_path File.expand_path(File.join(__dir__, '../app/views/'))

    super
  end

  def params
    {}
  end

  def helpers
    @helpers ||= Helpers.new
  end

  def request
    @_request = Session.new
    @request ||= Request.new
  end
end

class Helpers
  def pet_path(record = nil)
    "/pet/#{record&.id}"
  end

  def user_path(record = nil)
    "/user/#{record&.id}"
  end

  def edit_user_path(record)
    "/user/#{record.id}/edit"
  end

  def new_user_path(*args)
    '/users/new'
  end

  def render(*args)
    ActionController::Base.new.render_to_string(*args)
  end
end

class Request
  def path
    '/users/new'
  end

  def host
    'www.example.com'
  end

  def optional_port
    80
  end

  def protocol
    'http'
  end

  def path_parameters
    {}
  end

  def method_missing(*)
    nil
  end
end

class Session
  def session
    {}
  end
end

