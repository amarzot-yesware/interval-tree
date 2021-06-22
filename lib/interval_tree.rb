#!/usr/bin/env ruby

module IntervalTree

  class Tree
    def initialize(ranges, &range_factory)
      range_factory = lambda { |l, r| (l ... r+1) } unless block_given?
      ranges_excl = ensure_exclusive_end([ranges].flatten, range_factory)
      @top_node = divide_intervals(ranges_excl)
    end
    attr_reader :top_node

    def divide_intervals(intervals)
      return nil if intervals.empty?
      x_center = center(intervals)
      s_center = Array.new
      s_left = Array.new
      s_right = Array.new

      intervals.each do |k|
        case
        when k.end.to_r < x_center
          s_left << k
        when k.begin.to_r > x_center
          s_right << k
        else
          s_center << k
        end
      end
      Node.new(x_center, s_center,
               divide_intervals(s_left), divide_intervals(s_right))
    end

    # Search by range or point
    DEFAULT_OPTIONS = {unique: true, search_method: :intersects}
    def search(query, options = {})
      options = DEFAULT_OPTIONS.merge(options)

      return nil unless @top_node

      if query.respond_to?(:begin)
        result = top_node.public_send( options[:search_method], query)
        options[:unique] ? result.uniq : result
      else
        point_search(self.top_node, query, [], options[:unique])
      end
        .sort_by{|x|[x.begin, x.end]}
    end

    def intersects(query)
      search(query, search_method: :intersects)
    end

    def covers(query)
      search(query, search_method: :covers)
    end

    def covered_by(query)
      search(query, search_method: :covered_by)
    end

    def ==(other)
      top_node == other.top_node
    end

    private

    def ensure_exclusive_end(ranges, range_factory)
      ranges.map do |range|
        case
        when !range.respond_to?(:exclude_end?)
          range
        when range.exclude_end?
          range
        else
          range_factory.call(range.begin, range.end)
        end
      end
    end

    def center(intervals)
      (
        intervals.map(&:begin).min.to_r +
        intervals.map(&:end).max.to_r
      ) / 2
    end

    def point_search(node, point, result, unique = true)
      node.s_center.each do |k|
        if k.include?(point)
          result << k
        end
      end
      if node.left_node && ( point.to_r < node.x_center )
        point_search(node.left_node, point, []).each{|k|result << k}
      end
      if node.right_node && ( point.to_r >= node.x_center )
        point_search(node.right_node, point, []).each{|k|result << k}
      end
      if unique
        result.uniq
      else
        result
      end
    end
  end # class Tree

  class Node
    def initialize(x_center, s_center, left_node, right_node)
      @x_center = x_center
      @s_center = s_center
      @left_node = left_node
      @right_node = right_node
    end
    attr_reader :x_center, :s_center, :left_node, :right_node

    def ==(other)
      x_center == other.x_center &&
      s_center == other.s_center &&
      left_node == other.left_node &&
      right_node == other.right_node
    end

    # Search by range only
    def intersects(query)
      intersects_search_s_center(query) +
        (left_node && query.begin.to_r < x_center && left_node.intersects(query) || []) +
        (right_node && query.end.to_r > x_center && right_node.intersects(query) || [])
    end

    # Search for intervals which cover the query
    def covers(query)
      covers_search_s_center(query) +
        (left_node && query.begin.to_r < x_center && left_node.covers(query) || []) +
        (right_node && query.end.to_r > x_center && right_node.covers(query) || [])
    end

    # Search for intervals which are covered by the query
    def covered_by(query)
      covered_by_search_s_center(query) +
        (left_node && query.begin.to_r < x_center && left_node.covered_by(query) || []) +
        (right_node && query.end.to_r > x_center && right_node.covered_by(query) || [])
    end

    private

    def intersects_search_s_center(query)
      s_center.select do |k|
        query.begin < k.end && query.end > k.begin
      end
    end

    def covers_search_s_center(query)
      s_center.select do |k|
          # k than the query
          (k.begin <= query.begin) &&
            (k.end >= query.end)
      end
    end

    def covered_by_search_s_center(query)
      s_center.select do |k|
        # k is entirely contained within the query
        (k.begin >= query.begin) &&
          (k.end <= query.end)
      end
    end
  end # class Node

end # module IntervalTree
