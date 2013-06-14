module GitReview

  class Repository

    include ::GitReview::Accessible
    include ::GitReview::Deserializable
    extend ::GitReview::Nestable

    nests :owner => ::GitReview::User

    attr_accessor :name,
                  :full_name,
                  :private,
                  :html_url,
                  :description,
                  :fork,
                  :created_at,
                  :updated_at,
                  :pushed_at,
                  :open_issues_count,
                  :master_branch,
                  :default_branch

    def initialize(mash=nil)
      self.update_from_mash(mash) unless mash.nil?
    end

    def to_s
      @full_name
    end

  end

end