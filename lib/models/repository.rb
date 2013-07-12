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
                  :default_branch,
                  :parent

    def to_s
      @full_name
    end

    # @return [Repository, nil] parent of the forked repo
    def parent
      return unless fork
      @parent = ::GitReview::Github.instance.repository(@full_name)
    end

  end

end