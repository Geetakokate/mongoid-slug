#encoding: utf-8
require 'stringex'

module Mongoid #:nodoc:

  # Generates a URL slug or permalink based on one or more fields in a Mongoid
  # model.
  module Slug
    extend ActiveSupport::Concern

    included do
      cattr_accessor :slug_name, :slugged_fields
    end

    module ClassMethods

      # Sets one ore more fields as source of slug.
      #
      # By default, the name of the field that stores the slug is "slug". Pass an
      # alternative name with the :as option.
      #
      # If you wish the slug to be permanent once created, set :permanent to true.
      def slug(*fields)
        options = fields.extract_options!

        self.slug_name      = options[:as] || :slug
        self.slugged_fields = fields

        field slug_name

        if options[:permanent]
          before_create :generate_slug
        else
          before_save :generate_slug
        end
      end

      # Finds the document with the specified slug or returns nil.
      def find_by_slug(slug)
        where(slug_name => slug).first rescue nil
      end
    end

    def to_param
      self.send(slug_name)
    end

    private

    attr_reader :slug_counter

    def build_slug
      ("#{slug_base} #{slug_counter}").to_url
    end

    def find_unique_slug
      slug = build_slug
      if unique_slug?(slug)
        slug
      else
        increment_slug_counter
        find_unique_slug
      end
    end

    def generate_slug
      if new_record? || slugged_fields_changed?
        self.send("#{slug_name}=", find_unique_slug)
      end
    end

    def increment_slug_counter
      @slug_counter = (slug_counter.to_i + 1).to_s
    end

    def slug_base
      self.class.slugged_fields.map do |field|
        self.send(field)
      end.join(" ")
    end

    def slugged_fields_changed?
      self.class.slugged_fields.any? do |field|
        self.send("#{field}_changed?")
      end
    end

    def unique_slug?(slug)
      if embedded?
        _parent.send(association_name)
      else
        self.class
      end.
        where(slug_name => slug).
        reject { |doc| doc.id == self.id }.
        empty?
    end
  end
end
