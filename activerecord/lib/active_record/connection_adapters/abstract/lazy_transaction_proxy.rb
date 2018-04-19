# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class LazyTransactionProxy < SimpleDelegator # :nodoc:
      class StatementProxy < SimpleDelegator # :nodoc:
        def initialize(statement, connection)
          __setobj__(statement)
          @connection = connection
        end

        def respond_to_missing?(*)
          super
        end

        def method_missing(*)
          @connection.materialize_transactions
          super
        end
      end

      def initialize(connection)
        __setobj__(connection)
        @stack = []
        @materializing = false
        @use_lazy_transactions = true
      end

      def class
        __getobj__.class
      end

      def begin_transaction(&block)
        if @use_lazy_transactions
          @stack.push(block)
        else
          block.call
        end
      end

      def end_transaction(&block)
        if @stack.empty?
          block.call
        else
          @stack.pop
        end
      end

      def materialize_transactions
        return if @materializing

        begin
          @materializing = true
          @stack.shift.call until @stack.empty?
        ensure
          @materializing = false
        end
      end

      def disable_lazy_transactions!
        materialize_transactions
        @use_lazy_transactions = false
      end

      def enable_lazy_transactions!
        @use_lazy_transactions = true
      end

      def proxied_connection
        disable_lazy_transactions!
        __getobj__
      end

      def respond_to_missing?(*)
        super
      end

      def method_missing(*)
        materialize_transactions
        super
      end
    end
  end
end
