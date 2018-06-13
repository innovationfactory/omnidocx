module Omnidocx
  class Interpolator

    def initialize(replacement_hash, var_sub = nil, list_item_sub = nil)
      @replacements = replacement_hash
      @var_sub = var_sub || ->(var_name) { "%{#{var_name}}" }
      @list_item_sub = list_item_sub || ->(list_name, item_name) { "%{#{list_name}.#{item_name}}" }
    end

    def replace_vars(content)
      @replacements.each do |key,value|
        if value.is_a? Array
          content = perform_loop(content, key)
        else
          content.force_encoding('UTF-8').gsub!(@var_sub.call(key), value.to_s)
        end
      end
      content
    end

    protected

    def perform_loop(content, var_name)
      xml_tree = Nokogiri::XML(content)

      regex = /%{each:\s(#{var_name}[^}]*)}/
      regex.match content do |m|

        statement = m[0]
        params = m[1].split(',').map(&:strip)

        if params[2] == 'table'
          xml_tree = table_loop(xml_tree, statement, params)
        end
      end

      xml_tree.to_s.gsub(regex, '')
    end

    def table_loop(xml_tree, loop_statement, params)
      list_name, var_name, _, color1, color2 = *params
      table_head = xml_tree.xpath("//w:t[contains(., '#{loop_statement}')]/ancestor::w:tr").first

      template_row = table_head.next_sibling
      xml_str = template_row.to_s
      template_row.remove

      @replacements[list_name].each_with_index do |item_hash, index|
        new_row = xml_str.dup
        item_hash.each { |key, val| new_row.force_encoding('UTF-8').gsub!(@list_item_sub.call(var_name, key), val) }
        child = table_head.add_next_sibling(new_row)
        child.xpath('.//w:shd').attr('fill', index.even? ? color1 : color2 )
      end

      xml_tree
    end
  end
end
