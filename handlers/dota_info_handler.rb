require_relative '../util/violet_archives_helper'

class DotaInfoHandler < CommandHandler
  include VioletArchivesHelper

  feature :dota_info, default_enabled: false,
          description: 'Retrieves info about the game DotA 2'

  command(:dotahero, :show_hero)
    .feature(:dota_info).min_args(1).usage('dotahero [talents] <hero>')
    .description('Shows details of the given DotA Hero')

  command(:dotaitem, :show_item)
    .feature(:dota_info).min_args(1).usage('dotaitem <item>')
    .description('Shows details of the given DotA Item')

  command(:dotaability, :show_ability)
    .feature(:dota_info).min_args(1).usage('dotaability <ability>')
    .description('Shows details of the given DotA Ability')

  def config_name
    :dota
  end

  def show_hero(event, *name_input)
    show_talents = name_input.first.casecmp?('talents')
    name_input = name_input[1..-1] if show_talents

    name = name_input.join(' ')
    return 'Unrecognized.' if name.empty?

    entity_id = dota_dataset.hero_id_by_name(name)
    return 'Unrecognized.' if entity_id.nil?

    hero_info = dota_dataset.hero_data(entity_id)
    return "#{hero_info.name} Talents\n```#{format_hero_talents(hero_info.talents)}```" if show_talents

    event.channel.send_embed do |embed|
      build_hero_embed(embed, hero_info)
    end
  end

  def show_item(event, *name_input)
    name = name_input.join(' ')
    return 'Unrecognized.' if name.empty?

    entity_id = dota_dataset.item_id_by_name(name)
    return 'Unrecognized.' if entity_id.nil?

    event.channel.send_embed do |embed|
      build_item_embed(embed, dota_dataset.item_data(entity_id))
    end
  end

  def show_ability(event, *name_input)
    name = name_input.join(' ')
    return 'Unrecognized.' if name.empty?

    entity_id = dota_dataset.ability_id_by_name(name)
    return 'Unrecognized.' if entity_id.nil?

    event.channel.send_embed do |embed|
      build_ability_embed(embed, dota_dataset.ability_data(entity_id))
    end
  end

  private

  def dota_service
    @dota_service ||= create_dota_service(config.base_url, **config.service_urls)
  end

  def dota_dataset
    @dota_dataset ||= create_dota_dataset(dota_service)
  end

  def build_hero_embed(embed, hero_info)
    embed.author = { name: hero_info.name, icon_url: attribute_icon(hero_info.attribute) }
    embed.title = hero_info.short_desc
    embed.thumbnail = { url: "https://cdn.akamai.steamstatic.com/apps/dota2/images/dota_react/heroes/#{hero_info.name_id.gsub('npc_dota_hero_', '')}.png" }
    embed.description = "-# #{hero_info.complexity}-complexity #{hero_info.attack_type} Hero"
    add_hero_facets_fields(embed, hero_info.facets)
    add_hero_abilities_fields(embed, hero_info.abilities_ordered)
    embed
  end

  def attribute_icon(attribute_name)
    {
      'Strength' => 'https://cdn.akamai.steamstatic.com/apps/dota2/images/dota_react/icons/hero_strength.png',
      'Agility' => 'https://cdn.akamai.steamstatic.com/apps/dota2/images/dota_react/icons/hero_agility.png',
      'Intelligence' => 'https://cdn.akamai.steamstatic.com/apps/dota2/images/dota_react/icons/hero_intelligence.png',
      'Universal' => 'https://cdn.akamai.steamstatic.com/apps/dota2/images/dota_react/icons/hero_universal.png'
    }[attribute_name]
  end

  def add_hero_abilities_fields(embed, abilities)
    embed.add_field(name: 'Abilities', value: format_hero_abilities(abilities))

    while abilities.any?
      embed.add_field(name: '*Abilities continued*', value: format_hero_abilities(abilities))
    end
  end

  def format_hero_abilities(abilities)
    abils_list_str = ''

    loop do
      break if abilities.empty?

      abil_str = format_hero_ability(abilities.first)
      break if (abils_list_str + abil_str).length + 2 >= 1024

      abils_list_str += "\n#{abil_str}"
      abilities.shift
    end

    abils_list_str
  end

  def format_hero_ability(ability)
    label = '*Innate*' if ability.innate?
    label = '*Ultimate*' if ability.ult?
    label = '*Shard*' if ability.from_shard?
    label = '*Scepter*' if ability.from_scepter?

    "__#{ability.name}__ #{label}\n#{ability.short_desc}\n"
  end

  def add_hero_facets_fields(embed, facets)
    embed.add_field(name: 'Facets', value: format_hero_facets(facets))

    while facets.any?
      embed.add_field(name: '*Facets continued*', value: format_hero_facets(facets))
    end
  end

  def format_hero_facets(facets)
    facets_list_str = ''

    loop do
      break if facets.empty?

      facet = facets.first
      facet_str = "__#{facet.name}__\n#{facet.short_desc}\n"
      break if (facets_list_str + facet_str).length + 2 >= 1024

      facets_list_str += "\n#{facet_str}"
      facets.shift
    end

    facets_list_str
  end

  def format_hero_talents(talents)
    max_left_talent = talents.map { |pair| pair.first.name.length }.max
    talents.map.with_index { |pair, i| "#{pair.first.name.rjust(max_left_talent)} |#{(5 - i) * 5}| #{pair.last.name}" }.join("\n")
  end

  def build_item_embed(embed, item_info)
    embed.author = { name: item_info.name }
    embed
  end

  def build_ability_embed(embed, ability_info)
    embed.author = { name: ability_info.name }
    embed
  end
end
