module CallCenter
  module Test
    module DSL
      def self.included(base)
        base.send(:include, ActionController::Assertions::SelectorAssertions)
        base.extend(ClassMethods)
        base.class_eval do
          def response_from_page_or_rjs_with_body
            HTML::Document.new(CGI.unescapeHTML(@body)).root
          end
          alias_method_chain :response_from_page_or_rjs, :body
        end
      end

      def body(text, debug = false)
        puts text if debug
        @body = text
      end

      module ClassMethods
        def should_flow(options, &block)
          event = options.delete(:on)
          setup_block = options.delete(:when)
          setup_block_line = setup_block.to_s.match(/.*@(.*):([0-9]+)>/)[2] if setup_block
          state_field = self.call_center_state_field || options.delete(:state) || :state
          from, to = options.to_a.first
          description = ":#{from} => :#{to} via #{event}!#{setup_block_line.present? ? " when:#{setup_block_line}" : nil}"
          context "" do
            should "transition #{description}" do
              self.instance_eval(&setup_block) if setup_block
              @call.send(:"#{state_field}=", from.to_s)
              @call.send(:"#{event}")
              assert_equal to, @call.send(:"#{state_field}_name"), "status should be :#{to}, not :#{@call.send(state_field)}"
              if @call.respond_to?(:call_flow_run_deferred)
                @call.call_flow_run_deferred(:before_transition)
                @call.call_flow_run_deferred(:after_transition)
                @call.call_flow_run_deferred(:after_failure)
              end
            end

            if block.present?
              context "#{description} and :#{to}" do
                setup do
                  self.instance_eval(&setup_block) if setup_block
                  @call.send(:"#{state_field}=", from.to_s)
                  @call.send(:"#{event}")
                  body(@call.render) if @call.respond_to?(:render)
                  if @call.respond_to?(:call_flow_run_deferred)
                    @call.call_flow_run_deferred(:before_transition)
                    @call.call_flow_run_deferred(:after_transition)
                    @call.call_flow_run_deferred(:after_failure)
                  end
                end

                self.instance_eval(&block)
              end
            end
          end
        end

        def call_center_state_field(field = nil)
          field.nil? ? @_call_center_state_field : (@_call_center_state_field = field)
        end

        def should_also(&block)
          line = block.to_s.match(/.*@(.*):([0-9]+)>/)[2]
          should "also satisfy block on line #{line}" do
            self.instance_eval(&block)
          end
        end
        alias_method :and_also, :should_also

        def should_render(&block)
          line = block.to_s.match(/.*@(.*):([0-9]+)>/)[2]
          should "render selector on line #{line}" do
            args = [self.instance_eval(&block)].flatten
            assert_select *args
          end
        end
        alias_method :and_render, :should_render
      end
    end
  end
end
