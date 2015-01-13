desc "run all OSM-related tasks"
task :all_osm => [:osm_buildings]

# Actual Extent
n=45.7254175022529
e=-121.926452653623
s=45.2012894970606
w=-123.19651445735

# Test Extent
# n=45.57
# e=-122.68
# s=45.5
# w=-122.69
desc "Download buildings in OSM"
file 'osm/bldgs.osm' do |t|
  sh %Q{
wget -O - 'http://overpass-api.de/api/interpreter?data=
<osm-script>
  <osm-script output="xml">
    <union>
      <query type="way">
         <has-kv k="building"/>
        <bbox-query e="#{e}" n="#{n}" s="#{s}" w="#{w}"/>
      </query>
      <query type="node">
        <bbox-query e="#{e}" n="#{n}" s="#{s}" w="#{w}"/>
      </query>
      <query type="relation">
        <bbox-query e="#{e}" n="#{n}" s="#{s}" w="#{w}"/>
      </query>
    </union>
  <print mode="meta"/><!-- fixed by auto repair -->
    <recurse type="down"/>
  </osm-script>
</osm-script>
' > #{t.name}
}
# load the OSM data. Unfortunately, osm2pgsql creates
# four tables out of each input file, so we
# need to make sure we get update columns on them all,
# but we only load the data once (in :portland_osm_line)

 sh %Q{osmosis --read-xml osm/bldgs.osm --truncate-pgsql database=pdx_bldgs --wp database=pdx_bldgs }
end



# desc "Create OSM ways table from raw osmosis data. Used by osm_buildings"
# task :portland_osm  => 'osm/bldgs.osm' do |t|
# end

desc "Convert OSM ways into a buildings layer with appropriate tags"
table :osm_buildings => 'osm/bldgs.osm' do |t|
  t.drop_table
  t.run %Q{
  create table #{t.name} as
  select 
  id as way_id,
  tags -> 'access' as access,
  tags -> 'addr:housename' as addr_housename,
  tags -> 'addr:housenumber' as addr_housenumber,
  tags -> 'addr:interpolation' as addr_interpolation,
  tags -> 'addr:street' as addr_street,
  tags -> 'addr:postcode' as addr_postcode,
  tags -> 'addr:city' as addr_city,
  tags -> 'addr:unit' as addr_unit,
  tags -> 'addr:country' as addr_country,
  tags -> 'addr:full' as addr_full,
  tags -> 'addr:state' as addr_state,
  tags -> 'area' as area,
  tags -> 'building' as building,
  tags -> 'building:levels' as building_levels,
  tags -> 'construction' as construction,
  tags -> 'generator:source' as generator_source,
  tags -> 'man_made' as man_made,
  tags -> 'motorcar' as motorcar,
  tags -> 'name' as name,
  tags -> 'office' as office,
  tags -> 'place' as place,
  tags -> 'ref' as ref,
  tags -> 'religion' as religion,
  tags -> 'shop' as shop,
  st_setsrid(st_makepolygon(linestring),4326) as the_geom
  from ways
  where st_isclosed(linestring) and tags -> 'building' <> '';
}
  t.add_spatial_index
  t.add_update_column
end

desc "Convert nodes into address points"
table :osm_addrs => 'osm/bldgs.osm' do |t|
  t.drop_table
  t.run %Q{
    create table #{t.name} AS 
    select 
    id as node_id,
    tags -> 'addr:housename' as addr_housename,
    tags -> 'addr:housenumber' as addr_housenumber,
    tags -> 'addr:interpolation' as addr_interpolation,
    tags -> 'addr:street' as addr_street,
    tags -> 'addr:unit' as addr_unit,
    tags -> 'addr:postcode' as addr_postcode,
    tags -> 'addr:city' as addr_city,
    tags -> 'addr:country' as addr_country,
    tags -> 'addr:full' as addr_full,
    tags -> 'addr:state' as addr_state,
    geom as the_geom
    FROM nodes
    WHERE tags -> 'addr:street' <>'';
  }
  t.add_spatial_index
  t.add_update_column

 end