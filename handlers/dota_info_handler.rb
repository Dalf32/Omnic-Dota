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

  cache_object :dota_dataset, :build_dota_dataset

  def config_name
    :dota
  end

  def show_hero(event, *name_input)
    show_talents = name_input.first.casecmp?('talents')
    name_input = name_input[1..-1] if show_talents

    name = jargon_parser.translate_hero(name_input.join(' '))
    return 'Unrecognized.' if name.empty?

    event.channel.start_typing
    entity_id = dota_dataset.hero_id_by_name(name)
    return 'Unrecognized.' if entity_id.nil?

    hero_info = dota_dataset.hero_data(entity_id)
    return "#{hero_info.name} Talents\n```#{format_hero_talents(hero_info.talents)}```" if show_talents

    event.channel.send_embed do |embed|
      build_hero_embed(embed, hero_info)
    end
  end

  def show_item(event, *name_input)
    name = jargon_parser.translate_item(name_input.join(' '))
    return 'Unrecognized.' if name.empty?

    event.channel.start_typing
    entity_id = dota_dataset.item_id_by_name(name)
    return 'Unrecognized.' if entity_id.nil?

    event.channel.send_embed do |embed|
      build_item_embed(embed, dota_dataset.item_data(entity_id))
    end
  end

  def show_ability(event, *name_input)
    name = jargon_parser.translate_ability(name_input.join(' '))
    return 'Unrecognized.' if name.empty?

    event.channel.start_typing
    entity_id = dota_dataset.ability_id_by_name(name)
    return 'Unrecognized.' if entity_id.nil?

    event.channel.send_embed do |embed|
      build_ability_embed(embed, dota_dataset.ability_data(entity_id))
    end
  end

  private

  def build_dota_dataset
    create_dota_dataset(create_dota_service(config.base_url, **config.service_urls))
  end

  def dota_dataset
    if config.has_key?(:cache_time)
      cached_object(:dota_dataset, config.cache_time)
    else
      cached_object(:dota_dataset)
    end
  end

  def jargon_parser
    @jargon_parser ||= create_jargon_parser(config.hero_abbrevs, config.item_abbrevs)
  end

  def build_hero_embed(embed, hero_info)
    embed.author = { name: hero_info.name, icon_url: attribute_icon(hero_info.attribute) }
    embed.title = hero_info.short_desc
    embed.thumbnail = { url: "#{config.image_urls.hero_thumb_path}#{hero_info.name_id.gsub('npc_dota_hero_', '')}.png" }
    embed.description = "-# #{hero_info.complexity}-complexity #{hero_info.attack_type} Hero"
    add_hero_facets_fields(embed, hero_info.facets)
    add_hero_abilities_fields(embed, hero_info.abilities_ordered)
    embed
  end

  def attribute_icon(attribute_name)
    {
      'Strength' => config.image_urls.strength_icon,
      'Agility' => config.image_urls.agility_icon,
      'Intelligence' => config.image_urls.intelligence_icon,
      'Universal' => config.image_urls.universal_icon
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
    embed.title = item_info.neutral? ? "Tier #{item_info.neutral_tier} Neutral Item" : "#{item_info.gold_cost} Gold Cost Item"
    embed.thumbnail = { url: "#{config.image_urls.item_thumb_path}#{item_info.name_id.gsub('item_', '')}.png" }
    embed.description = item_info.short_desc
    add_common_ability_fields(embed, item_info) if item_info.ability?
    add_bonus_values_field(embed, item_info.bonus_values)
    embed
  end

  def add_bonus_values_field(embed, bonus_values)
    return if bonus_values.empty?

    embed.add_field(name: 'Bonuses', value: bonus_values.map { |val| "+#{val.values.first} #{val.heading}" }.join("\n"))
  end

  def add_common_ability_fields(embed, ability_info)
    add_ability_properties_field(embed, ability_info)
    add_ability_details_field(embed, ability_info)
    add_ability_cost_field(embed, ability_info)
  end

  def add_ability_properties_field(embed, ability_info)
    properties_detail = "Ability: #{ability_info.target_type}"
    properties_detail += "\nAffects: #{ability_info.target_team} #{ability_info.target_affects}" unless ability_info.no_target?
    properties_detail += "\nDamage Type: #{ability_info.damage_type}" unless ability_info.no_damage?
    properties_detail += "\nPierces Spell Immunity: #{ability_info.pierces_spell_immunity? ? 'Yes' : 'No'}" if ability_info.anything_to_pierce?
    properties_detail += "\nDispellable: #{ability_info.dispellable}" if ability_info.anything_to_dispel?

    embed.add_field(name: 'Properties', value: properties_detail)
  end

  def add_ability_details_field(embed, ability_info)
    return if ability_info.ability_values.empty?

    details = ability_info.ability_values.map { |val| "#{val.heading} #{val.values_str}" }.join("\n")
    details += "\n\nCooldown: #{ability_info.cooldowns.join('/')}" if ability_info.cooldowns?

    embed.add_field(name: 'Details', value: details, inline: true)
  end

  def add_ability_cost_field(embed, ability_info)
    cost = ''
    cost += "Mana: #{ability_info.mana_costs.join('/')}\n" if ability_info.mana_costs?
    cost += "Health: #{ability_info.health_costs.join('/')}" if ability_info.health_costs?

    embed.add_field(name: 'Cost', value: cost, inline: true) unless cost.empty?
  end

  def build_ability_embed(embed, ability_info)
    embed.author = { name: ability_info.name }
    embed.thumbnail = { url: "#{config.image_urls.ability_thumb_path}#{ability_info.name_id}.png" }
    embed.description = ability_info.short_desc
    add_common_ability_fields(embed, ability_info)
    add_aghs_upgrade_fields(embed, ability_info)
    embed
  end

  def add_aghs_upgrade_fields(embed, ability_info)
    embed.add_field(name: 'Scepter Upgrade', value: ability_info.scepter_desc) if ability_info.scepter_upgrade?
    embed.add_field(name: 'Shard Upgrade', value: ability_info.shard_desc) if ability_info.shard_upgrade?
  end
end
