class ForkedRepository < Repository

  extend Nestable

  nests parent: Repository
end
