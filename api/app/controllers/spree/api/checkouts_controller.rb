module Spree
  module Api
    class CheckoutsController < Spree::Api::BaseController
      before_action :associate_user, only: :update
      before_action :load_order_with_lock, only:[:next, :advance, :update]
      before_action :validate_line_items_availability, only:[:update]

      include Spree::Core::ControllerHelpers::Auth
      include Spree::Core::ControllerHelpers::Order
      # This before_filter comes from Spree::Core::ControllerHelpers::Order
      skip_before_action :set_current_order

      def next
        authorize! :update, @order, order_token
        @order.next!
        respond_with(@order, default_template: 'spree/api/orders/show', status: 200)
      rescue StateMachines::InvalidTransition
        respond_with(@order, default_template: 'spree/api/orders/could_not_transition', status: 422)
      end

      def advance
        authorize! :update, @order, order_token
        while @order.next; end
        respond_with(@order, default_template: 'spree/api/orders/show', status: 200)
      end

      def update
        authorize! :update, @order, order_token

        if @order.update_from_params(params, permitted_checkout_attributes, request.headers.env)
          if current_api_user.has_spree_role?('admin') && user_id.present?
            @order.associate_user!(Spree.user_class.find(user_id))
          end

          return if after_update_attributes

          if @order.completed? || @order.next
            state_callback(:after)
            respond_with(@order, default_template: 'spree/api/orders/show')
          else
            respond_with(@order, default_template: 'spree/api/orders/could_not_transition', status: 422)
          end
        else
          invalid_resource!(@order)
        end
      end

      private
        def user_id
          params[:order][:user_id] if params[:order]
        end

        def nested_params
          map_nested_attributes_keys Spree::Order, params[:order] || {}
        end

        # Should be overriden if you have areas of your checkout that don't match
        # up to a step within checkout_steps, such as a registration step
        def skip_state_validation?
          false
        end

        def load_order(lock = false)
          @order = Spree::Order.lock(lock).find_by!(number: params[:id])
          @order.state = params[:state] if params[:state]
          state_callback(:before)
        end

        def load_order_with_lock
          load_order(true)
        end

        def validate_line_items_availability
          unless params[:order].try(:[],:payments_attributes).blank? || @order.completed?
            unless @order.ensure_line_items_are_in_stock
              respond_with(@order, default_template: 'spree/api/orders/could_not_transition', status: 422)
            end
          end
        end

        def state_callback(before_or_after = :before)
          method_name = :"#{before_or_after}_#{@order.state}"
          send(method_name) if respond_to?(method_name, true)
        end

        def after_update_attributes
          if nested_params && nested_params[:coupon_code].present?
            handler = Spree::PromotionHandler::Coupon.new(@order).apply

            if handler.error.present?
              @coupon_message = handler.error
              respond_with(@order, default_template: 'spree/api/orders/could_not_apply_coupon')
              return true
            end
          end
          false
        end

        def order_id
          super || params[:id]
        end
    end
  end
end
