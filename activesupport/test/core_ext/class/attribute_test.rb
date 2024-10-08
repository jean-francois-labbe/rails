# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/class/attribute"

class ClassAttributeTest < ActiveSupport::TestCase
  def setup
    @klass = Class.new do
      class_attribute :setting
      class_attribute :timeout, default: 5
      class_attribute :system # private kernel method
    end

    @sub = Class.new(@klass)
  end

  test "defaults to nil" do
    assert_nil @klass.setting
    assert_nil @sub.setting
  end

  test "custom default" do
    assert_equal 5, @klass.timeout
  end

  test "inheritable" do
    @klass.setting = 1
    assert_equal 1, @sub.setting
  end

  test "overridable" do
    @sub.setting = 1
    assert_nil @klass.setting
    assert_equal 1, @sub.setting

    @klass.setting = 2
    assert_equal 2, @klass.setting
    assert_equal 1, @sub.setting

    assert_equal 1, Class.new(@sub).setting
    assert_equal 2, Class.new(@klass).setting
  end

  test "predicate method" do
    assert_equal false, @klass.setting?
    @klass.setting = 1
    assert_equal true, @klass.setting?
  end

  test "instance reader delegates to class" do
    assert_nil @klass.new.setting

    @klass.setting = 1
    assert_equal 1, @klass.new.setting
  end

  test "instance override" do
    object = @klass.new
    object.setting = 1
    assert_nil @klass.setting
    @klass.setting = 2
    assert_equal 1, object.setting
  end

  test "instance predicate" do
    object = @klass.new
    assert_equal false, object.setting?
    object.setting = 1
    assert_equal true, object.setting?
  end

  test "disabling instance writer" do
    object = Class.new { class_attribute :setting, instance_writer: false }.new
    assert_raise(NoMethodError) { object.setting = "boom" }
    assert_not_respond_to object, :setting=
  end

  test "disabling instance reader" do
    object = Class.new { class_attribute :setting, instance_reader: false }.new
    assert_raise(NoMethodError) { object.setting }
    assert_not_respond_to object, :setting
    assert_raise(NoMethodError) { object.setting? }
    assert_not_respond_to object, :setting?
  end

  test "disabling both instance writer and reader" do
    object = Class.new { class_attribute :setting, instance_accessor: false }.new
    assert_raise(NoMethodError) { object.setting }
    assert_not_respond_to object, :setting
    assert_raise(NoMethodError) { object.setting? }
    assert_not_respond_to object, :setting?
    assert_raise(NoMethodError) { object.setting = "boom" }
    assert_not_respond_to object, :setting=
  end

  test "disabling instance predicate" do
    object = Class.new { class_attribute :setting, instance_predicate: false }.new
    assert_raise(NoMethodError) { object.setting? }
    assert_not_respond_to object, :setting?
  end

  test "works well with singleton classes" do
    object = @klass.new

    object.singleton_class.setting = "foo"
    assert_equal "foo", object.setting
    assert_nil @klass.setting

    object.singleton_class.setting = "bar"
    assert_equal "bar", object.setting
    assert_nil @klass.setting

    @klass.setting = "plop"
    assert_equal "bar", object.setting
    assert_equal "plop", @klass.setting
  end

  test "when defined in a class's singleton" do
    @klass = Class.new do
      class << self
        class_attribute :__callbacks, default: 1
      end
    end

    assert_equal 1, @klass.__callbacks
    assert_equal 1, @klass.singleton_class.__callbacks

    # I honestly think this is a bug, but that's how it used to behave
    @klass.__callbacks = 4
    assert_equal 1, @klass.__callbacks
    assert_equal 1, @klass.singleton_class.__callbacks
  end

  test "works well with module singleton classes" do
    @module = Module.new do
      class << self
        class_attribute :settings, default: 42
      end
    end

    assert_equal 42, @module.settings
  end

  test "setter returns set value" do
    val = @klass.public_send(:setting=, 1)
    assert_equal 1, val
  end

  test "works when overriding private methods from an ancestor" do
    assert_nil @klass.system
    @klass.system = 1
    assert_equal 1, @klass.system

    instance = @klass.new
    assert_equal 1, instance.system
    assert_predicate @klass.new, :system?
    instance.system = 2
    assert_equal 2, instance.system
  end
end
