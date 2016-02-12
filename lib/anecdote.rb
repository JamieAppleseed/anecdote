require "raconteur"
require "kramdown"
require "anecdote/engine"

module Anecdote

  def self.markdown_and_parse(content="")
    ::Kramdown::Document.new( raconteur.parse(content), { input: :GFM } ).to_html.html_safe
  end

  def self.raconteur
    @raconteur ||= ::Raconteur.new
  end

  def self.inline_js
    view_context.content_tag(:script, Rails.application.assets.find_asset('anecdote/application.js').to_s.html_safe)
  end

  def self.init_raconteur
    raconteur.settings.setting_quotes = '$'

    raconteur.processors.register!('graphic', {
      handler: lambda do |settings|
        klass = (['anecdote-graphic-dn32ja'] + module_classes(settings)).flatten.join(' ')
        contents = []
        contents << view_context.content_tag((settings[:href].present? ? :a : :div), (settings[:href].present? ? { href: settings[:href], title: settings[:href_title] } : {}).merge({ class: 'anecdote-intrinsic-embed-n42ha1' })) do
          if settings[:assets_path]
            content = view_context.image_tag(settings[:assets_path], alt: '')
            paperclip_geo = Paperclip::Geometry.from_file(Rails.root.join('app', 'assets', 'images', settings[:assets_path]))
            geo = { width: paperclip_geo.width, height: paperclip_geo.height }
          elsif settings[:image_url]
            content = view_context.image_tag(settings[:image_url], alt: '')
            dimensions = (settings[:dimensions] || settings[:image_dimensions]).split('x').map(&:to_f)
            geo = { width: dimensions.first, height: dimensions.last }
          elsif settings[:embed_code]
            content = settings[:embed_code].html_safe
            dimensions = settings[:dimensions].split('x').map(&:to_f)
            geo = { width: dimensions.first, height: dimensions.last }
          end
          if settings[:_scope_].present? && settings[:_scope_][:processor].tag == 'gallery'
            settings[:_scope_][:settings][:_graphics_] ||= []
            settings[:_scope_][:settings][:_graphics_] << geo
          end
          view_context.content_tag(:div, content, class: 'inner', style: "padding-bottom: #{geo[:height] / geo[:width] * 100}%;")
        end
        if settings[:caption].present?
          contents << view_context.content_tag(:div, view_context.content_tag(:div, markdown_and_parse(settings[:caption]), class: 'inner anecdote-wysicontent-ndj4ab'), class: 'anecdote-caption-ajkd3b')
        end
        view_context.content_tag(:div, view_context.content_tag(:div, contents.join("\n").html_safe, class: 'inner'), class: klass)
      end
      })

    raconteur.processors.register!('gallery', {
      handler: lambda do |settings|
        klasses = ['anecdote-gallery-dn2bak']
        klasses += module_classes(settings)
        graphics = settings[:_yield_].html_safe

        # handle scaling
        flexes = []
        if settings[:flexes]
          flexes = parse_custom_flexes(settings)
        else
          if settings[:scale_by] == 'relative-width-bottom-alignment'
            # images scaled based on their relative width with bottom alignment
            total_width = settings[:_graphics_].sum { |hsh| hsh[:width]}
            settings[:_graphics_].each do |graphic|
              flex = {
                width: graphic[:width] / total_width,
                graphic: graphic,
                ratio: graphic[:width] / graphic[:height],
                gfx_height_pad: graphic[:height] / graphic[:width]
              }
              flex[:width_ratio_balance] = flex[:width] / flex[:ratio]
              flexes << flex
            end
            tallest = flexes.sort_by { |k| k[:width_ratio_balance] }.last
            flexes.map do |flex|
              flex[:faux] = flex[:width_ratio_balance] / tallest[:width_ratio_balance]
              flex[:gfx_height_pad_faux] = flex[:gfx_height_pad] / flex[:faux]
              flex[:top_offset] = flex[:gfx_height_pad_faux] - flex[:gfx_height_pad]
            end
            index = 0
            graphics.gsub!('<div class="anecdote-intrinsic-embed-n42ha1">') do |match|
              flex = flexes[index]
              index += 1
              (view_context.content_tag(:div, '', class: 'anecdote-flex-offset-a4j2aj', style: "padding-top: #{flex[:top_offset] * 100}%;").html_safe + match.html_safe).html_safe
            end
            # graphics.gsub!(/anecdote-intrinsic-embed-n42ha1.*?padding-bottom:\s*([\d|\.]*)/mi) do |match|
            #   flex = flexes[index]
            #   index += 1
            #   match.sub(/[\d|\.]*$/, (flex[:gfx_height_pad_faux] * 100).to_s).html_safe
            # end
          elsif settings[:scale_by] == 'relative-width'
            # images scaled based on their relative width
            total_width = settings[:_graphics_].sum { |hsh| hsh[:width]}
            settings[:_graphics_].each do |graphic|
              flexes << { width: graphic[:width] / total_width, graphic: graphic }
            end
          else
            # images scaled to equal height
            total_ratio = settings[:_graphics_].sum { |geo| geo[:width] / geo[:height] }
            settings[:_graphics_].each do |graphic|
              flexes << { width: (graphic[:width] / graphic[:height]) / total_ratio, graphic: graphic }
            end
          end
        end
        graphics = insert_flex_basis_styles(graphics, flexes)

        # build HTML output
        contents = []
        settings[:gutter_spacing] = 'small' if settings[:gutter_spacing].blank?
        contents << view_context.content_tag(:div, graphics.html_safe, class: (['content'] + flex_classes(settings)).flatten.join(' '))
        if settings[:caption].present?
          contents << view_context.content_tag(:div, view_context.content_tag(:div, markdown_and_parse(settings[:caption]), class: 'inner anecdote-wysicontent-ndj4ab'), class: 'anecdote-caption-ajkd3b')
        end
        view_context.content_tag(:div, view_context.content_tag(:div, contents.join("\n").html_safe, class: 'inner'), class: klasses.flatten.join(' '))
      end
      })

    raconteur.processors.register!('columns', {
      handler: lambda do |settings|
        klasses = ['anecdote-columns-nab3a2']
        klasses += module_classes(settings)
        columns = insert_flex_basis_styles(settings[:_yield_].html_safe, parse_custom_flexes(settings))
        view_context.content_tag(:div, view_context.content_tag(:div, columns.html_safe, class: (['inner'] + flex_classes(settings)).flatten.join(' ')), class: klasses.flatten.join(' '))
      end
      })

    raconteur.processors.register!('anecdote', {
      handler: lambda do |settings|
        klass = (['anecdote-inception-ab2a8j'] + module_classes(settings)).flatten.join(' ')
        view_context.content_tag(:div, view_context.content_tag(:div, markdown_and_parse(settings[:_yield_]), class: 'anecdote-wysicontent-ndj4ab inner'), class: klass)
      end
      })

    raconteur.processors.register!('pull-quote', {
      handler: lambda do |settings|
        klass = (['anecdote-pull-quote-sba2ha'] + module_classes(settings)).flatten.join(' ')
        view_context.content_tag(:div, view_context.content_tag(:div, markdown_and_parse(settings[:text]), class: 'inner'), class: klass)
      end
      })
  end


  def self.parse_custom_flexes(settings)
    ratios = settings[:flexes].split(':').map(&:to_i)
    sum = ratios.inject(&:+)
    flexes = ratios.map { |ratio| { width: ratio.to_f / sum } }
  end
  def self.insert_flex_basis_styles(html_content, flexes)
    index = 0
    doc = Nokogiri::HTML::DocumentFragment.parse(html_content)
    doc.elements.each do |element|
      if element.attributes['class'].present? && element.attributes['class'].value.split(' ').include?('anecdote-module-3ba83n')
        flex = flexes[index]
        index += 1
        styles = []
        if flex[:width].present?
          styles << "-webkit-flex-basis:#{flex[:width] * 100}%"
          styles << "-moz-flex-basis:#{flex[:width] * 100}%"
          styles << "flex-basis:#{flex[:width] * 100}%"
        end
        element.set_attribute('style', styles.join(';'))
      end
    end
    doc.to_html
  end
  def self.flex_classes(settings)
    klasses = %w(anecdote-flex-module-a4j2aj)
    # custom gutter spacing
    klasses << case settings[:gutter_spacing]
    when 'small' then 'v-gutter-spacing-small'
    when 'large' then 'v-gutter-spacing-large'
    end
    # when to wrap
    klasses << case settings[:flow_from]
    when 'always' then 'v-flow-from-always'
    when 'medium-handheld' then 'v-flow-from-medium-handheld'
    when 'large-handheld' then 'v-flow-from-large-handheld'
    when 'tablet' then 'v-flow-from-tablet'
    when 'laptop' then 'v-flow-from-laptop'
    when 'large-monitor' then 'v-flow-from-large-monitor'
    else
      if settings[:size].present?
        case settings[:size]
        when 'small' then 'v-flow-from-medium-handheld'
        when 'medium' then 'v-flow-from-large-handheld'
        when 'big' then 'v-flow-from-tablet'
        when 'full-width' then 'v-flow-from-tablet'
        end
      else
        'v-flow-from-tablet' # default
      end
    end
    klasses
  end

  def self.module_classes(settings)
    klasses = %w(anecdote-module-3ba83n)
    if settings[:size].present?
      klasses << case settings[:size]
      when 'small' then 'v-size-small'
      when 'medium' then 'v-size-medium'
      when 'big' then 'v-size-big'
      when 'full-width' then 'v-size-full-width'
      end
    end
    if settings[:float].present?
      klasses << case settings[:float]
      when 'right' then 'v-float-right'
      when 'left' then 'v-float-left'
      end
      klasses << case settings[:float_from]
      when 'always' then 'v-float-from-always'
      when 'medium-handheld' then 'v-float-from-medium-handheld'
      when 'large-handheld' then 'v-float-from-large-handheld'
      when 'tablet' then 'v-float-from-tablet'
      when 'laptop' then 'v-float-from-laptop'
      when 'large-monitor' then 'v-float-from-large-monitor'
      else
        if settings[:size].present?
          case settings[:size]
          when 'small' then 'v-float-from-large-handheld'
          when 'medium' then 'v-float-from-laptop'
          when 'big' then 'v-flow-from-large-monitor'
          end
        else
          'v-float-from-laptop' # default
        end
      end
    end
    if settings[:mood].present?
      klasses << case settings[:mood]
      when 'positive' then 'v-mood-positive'
      when 'negative' then 'v-mood-negative'
      end
    end
    klasses
  end



  private

  def self.view_context
    Anecdote::ApplicationController.helpers
  end

end

Anecdote.init_raconteur
