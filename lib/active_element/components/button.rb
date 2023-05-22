# frozen_string_literal: true

module ActiveElement
  module Components
    # A clickable button.
    # rubocop:disable Metrics/ClassLength
    class Button
      # rubocop:disable Metrics/MethodLength
      def initialize(controller, record, flag_or_options, confirm: false, type: :primary, method: nil,
                     float: nil, icon: nil, **kwargs, &block)
        @controller = controller
        @record = record.is_a?(ActiveRecord::Relation) ? record.klass.new : record
        @flag_or_options = flag_or_options
        @float = float
        @kwargs = kwargs
        @kwargs_class = kwargs.delete(:class)
        @confirm = confirm
        @type = type
        @method = method
        @icon = icon
        @block_given = block_given?
        @content = block.call if block_given?
      end
      # rubocop:enable Metrics/MethodLength

      def template
        'active_element/components/button'
      end

      def locals # rubocop:disable Metrics/MethodLength
        {
          controller: controller,
          method: link_method,
          path: resource_path,
          confirm: confirm,
          type: type,
          title: title,
          float_class: float_class,
          icon: icon,
          button_class: button_class,
          kwargs_class: kwargs_class,
          kwargs: kwargs,
          content: content,
          block_given: block_given
        }
      end

      private

      attr_reader :controller, :record, :flag_or_options, :float, :kwargs, :kwargs_class, :type, :method, :icon,
                  :block_given, :content, :confirm

      def link_method
        return method if method.present?

        { show: :get, destroy: :delete, new: :get, edit: :get }.fetch(type, :get)
      end

      def button_class # rubocop:disable Metrics/MethodLength
        case type
        when :destroy
          'btn-danger destroy-button action-button'
        when :show
          'btn-primary show-button action-button'
        when :edit
          'btn-primary edit-button action-button'
        when :new
          'btn-primary new-button action-button'
        else
          "btn-#{type}"
        end
      end

      def float_class
        { 'end' => 'float-end', 'start' => 'float-start', nil => nil }.fetch(float)
      end

      def namespace_prefix
        # XXX: We guess the namespace from the current controller's module name. This will work
        # most of the time but will break the current record's controller exists in a different
        # namespace to the current controller, e.g. `BackEndAdmin::UsersController` and
        # `FrontEndAdmin::ThemesController` - if `FrontEndAdmin::ThemesController` renders a
        # collection of `User` objects, the "show" path will be wrong:
        # `front_end_admin_user_path`. Maybe descend through the full controller class tree to
        # find a best match ?
        namespace = controller.class.name.deconstantize.underscore
        return nil if namespace.blank?

        "#{namespace}_"
      end

      def record_path
        return nil if record.nil?

        controller.helpers.public_send(default_record_path, record)
      rescue NoMethodError
        controller.helpers.public_send(sti_record_path, record)
      end

      def default_record_path
        "#{record_path_prefix}#{namespace_prefix}#{record_name}_path"
      end

      def sti_record_path
        "#{record_path_prefix}#{namespace_prefix}#{sti_record_name}_path"
      end

      def record_path_prefix
        case type
        when :edit
          'edit_'
        when :new
          'new_'
        end
      end

      def title
        return flag_or_options[:title] if flag_or_options.is_a?(Hash) && flag_or_options[:title].present?
        return default_action_title if %i[show destroy edit new].include?(type)

        kwargs.fetch(:title, '')
      end

      def default_action_title
        return 'View' if type == :show
        return 'Delete' if type == :destroy
        return 'Edit' if type == :edit
        return "Create New #{(sti_record_name || record_name).titleize}" if type == :new
      end

      def resource_path
        return record_path if flag_or_options == true && record.present?
        return nil if !flag_or_options.is_a?(Hash) && record.blank?
        return resource_path_from_options if resource_path_from_options.present?

        record_path
      end

      def resource_path_from_options
        return nil unless flag_or_options.is_a?(Hash)
        return flag_or_options[:path].call(record) if flag_or_options[:path].is_a?(Proc)

        flag_or_options[:path]
      end

      def record_name
        Util.record_name(record)
      end

      def sti_record_name
        Util.sti_record_name(record)
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
