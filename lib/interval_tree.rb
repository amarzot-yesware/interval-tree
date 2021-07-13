#!/usr/bin/env ruby

module IntervalTree

  class Tree
    def initialize(ranges, &range_factory)
      range_factory = lambda { |l, r| (l ... r+1) } unless block_given?
      ranges_excl = ensure_exclusive_end([ranges].flatten, range_factory)
      @top_node = construct_tree(ranges_excl)
    end
    attr_reader :top_node

    def construct_tree(intervals)
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
               construct_tree(s_left), construct_tree(s_right))
    end

    # Search by range or point
    DEFAULT_OPTIONS = {unique: true}
    def search(query, options = {})
      options = DEFAULT_OPTIONS.merge(options)

      return nil unless @top_node

      if query.respond_to?(:begin)
        result = top_node.search(query)
        options[:unique] ? result.uniq : result
      else
        point_search(self.top_node, query, [], options[:unique])
      end
        .sort_by{|x|[x.begin, x.end]}
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
        if k.begin <= point && point < k.end
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
      @begin_sorted = s_center.sort_by {|i| i.begin}
      @end_rsorted = s_center.sort_by {|i| i.end}.reverse
      @left_node = left_node
      @right_node = right_node
    end
    attr_reader :x_center, :begin_sorted, :end_rsorted, :left_node, :right_node
    alias :s_center :begin_sorted

    def ==(other)
      x_center == other.x_center &&
      begin_sorted == other.begin_sorted &&
      end_rsorted == other.end_rsorted &&
      left_node == other.left_node &&
      right_node == other.right_node
    end

    # Search by range only
    def search(query)
      search_node_bsearch(query) +
        (left_node && query.begin.to_r < x_center && left_node.search(query) || []) +
        (right_node && query.end.to_r > x_center && right_node.search(query) || [])
    end

    private

    def search_node_bsearch(query)
      if query.end.to_r < x_center
        # Query interval is entirely left of center
        index = begin_sorted.bsearch_index {|i| i.begin >= query.end}
        return begin_sorted unless index
        begin_sorted.take index
      elsif query.begin.to_r >= x_center
        # Query interval is entirely right of center
        index = end_rsorted.bsearch_index {|i| i.end <= query.begin}
        return end_rsorted unless index
        end_rsorted.take index
      else
        # Query interval contains center, thus intersects all
        begin_sorted
      end
    end

  end # class Node

end # module IntervalTree
