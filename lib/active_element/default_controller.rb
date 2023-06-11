module ActiveElement
  class DefaultController
    def initialize(controller:)
      @controller = controller
    end

    def index
      controller.render 'active_element/default_views/index',
             locals: {
               collection: text_search? ? model.left_outer_joins(search_relations).where(*text_search) : model.all,
               search_filters: search_filters
             }
    end

    def show
      controller.render 'active_element/default_views/show', locals: { record: record }
    end

    def new
      controller.render 'active_element/default_views/new', locals: { record: model.new, namespace: namespace }
    end

    def create
      new_record = model.new(default_record_params)
      if new_record.save && new_record.reload.update(default_record_params) # Ensure associations are applied.
        controller.flash.notice = "#{new_record.model_name.to_s.titleize} created successfully."
        controller.redirect_to record_path(new_record, :show).path
      else
        controller.flash.now.alert = "Failed to create #{model.name.to_s.titleize}."
        controller.render 'active_element/default_views/new', locals: { record: new_record, namespace: namespace }
      end
    end

    def edit
      controller.render 'active_element/default_views/edit', locals: { record: record, namespace: namespace }
    end

    def update
      if record.update(default_record_params)
        controller.flash.notice = "#{record.model_name.to_s.titleize} updated successfully."
        controller.redirect_to record_path(record, :show).path
      else
        controller.flash.now.alert = "Failed to update #{model.name.to_s.titleize}."
        controller.render 'active_element/default_views/edit', locals: { record: record, namespace: namespace }
      end
    end

    def destroy
      record.destroy
      controller.flash.notice = "Deleted #{record.model_name.to_s.titleize}."
      controller.redirect_to record_path(model, :index).path
    end

    private

    attr_reader :controller

    def record_path(record, type = nil)
      ActiveElement::Components::Util::RecordPath.new(record: record, controller: controller, type: type)
    end

    def namespace
      controller.controller_path.rpartition('/').first.presence&.to_sym
    end

    def search_filters
      controller.params.permit(*searchable_fields).transform_values do |value|
        value.try(:compact_blank) || value
      end.compact_blank
    end

    def text_search
      conditions = search_filters.to_h.map do |key, value|
        next relation_matches(key, value) if relation?(key)
        next datetime_between(key, value) if datetime?(key)

        model.arel_table[key].matches("#{value}%")
      end
      conditions[1..].reduce(conditions.first) do |accumulated, condition|
        accumulated.and(condition)
      end
    end

    def text_search?
      search_filters.present?
    end

    def relation?(attribute)
      relation(attribute.to_sym).present?
    end

    def relation(attribute)
      model.reflect_on_association(attribute.to_sym)
    end

    def search_relations
      search_filters.to_h.keys.map { |key| relation?(key) ? key.to_sym : nil }.compact
    end

    def datetime?(key)
      model.columns.find { |column| column.name.to_s == key.to_s }&.type == :datetime
    end

    def datetime_between(key, value)
      return noop if value[:from].blank? && value[:to].blank?

      offset = controller.request.cookies['timezone_offset'].to_i.minutes
      range_begin = value[:from].present? ? Time.zone.parse(value[:from]) + offset : -Float::INFINITY
      range_end = value[:to].present? ? Time.zone.parse(value[:to]) + offset : Float::INFINITY

      model.arel_table[key].between(range_begin...range_end)
    end

    def relation_matches(key, value)
      fields = searchable_relation_fields(key)
      relation_model = relation(key).klass
      fields.select! do |field|
        relation_model.columns.find { |column| column.name.to_s == field.to_s }&.type == :string
      end

      return noop if fields.empty?

      fields[1..].reduce(relation_model.arel_table[fields.first].matches("#{value}%")) do |condition, field|
        condition.or(relation_model.arel_table[field].matches("#{value}%"))
      end
    end

    def searchable_relation_fields(key)
      Components::Util.relation_controller(model, controller, key)
                      &.active_element
                      &.state
                      &.fetch(:searchable_fields, []) || []
    end

    def noop
      Arel::Nodes::True.new.eq(Arel::Nodes::True.new)
    end

    def model
      controller.controller_name.classify.constantize
    end

    def record
      @record ||= model.find(controller.params[:id])
    end

    def default_record_params
      with_transformed_relations(
        controller.params.require(controller.controller_name.singularize)
                  .permit(controller.active_element.state.fetch(:editable_fields, []))
      )
    end

    def with_transformed_relations(params)
      params.to_h.to_h do |key, value|
        next [key, value] unless relation?(key)

        case relation(key).macro
        when :belongs_to
          [relation(key).foreign_key, value]
        when :has_one
          [relation(key).name, relation(key).klass.find_by(relation(key).klass.primary_key => value)]
        when :has_many
          [relation(key).name, relation(key).klass.where(relation(key).klass.primary_key => relation(key).value)]
        end
      end
    end

    def searchable_fields
      base_fields = controller.active_element.state.fetch(:searchable_fields, [])
      base_fields.map do |field|
        next field unless field.to_s.end_with?('_at')

        { field => [:from, :to] }
      end
    end
  end
end
