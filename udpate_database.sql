ALTER TABLE master_address ALTER column fdpre type varchar(10);
ALTER TABLE master_address ALTER column fdsuf type varchar(10);
ALTER TABLE master_address ALTER column ftype type varchar(20);
-- ALTER TABLE bldgs_2013_03_06 ADD COLUMN tlid varchar(20);
ALTER TABLE bldgs_2013_03_06 ADD COLUMN neighborhood varchar(60);
-- ALTER TABLE bldgs_2013_03_06 ADD COLUMN centroid geometry(Point,2913);
-- UPDATE bldgs_2013_03_06 SET geom=st_makevalid(geom) WHERE NOT st_isvalid(geom);
-- UPDATE bldgs_2013_03_06 SET centroid=st_pointonsurface(geom);
-- UPDATE bldgs_2013_03_06 b SET tlid=t.tlid FROM taxlots t WHERE st_intersects(b.centroid,t.geom);
UPDATE pdx_addrs b SET neighborhood=n.name FROM nbo_hood n WHERE st_intersects(b.centroid,n.geom);

UPDATE master_address SET
  fname=initcap(regexp_replace(fname, E'"','','g')),
  fdpre=CASE fdpre
        WHEN 'N' THEN 'North'
        WHEN 'S' THEN 'South'
        WHEN 'E' THEN 'East'
        WHEN 'W' Then 'West'
        WHEN 'NW' THEN 'Northwest'
        WHEN 'SW' THEN 'Southwest'
        WHEN 'NE' THEN 'Northeast'
        WHEN 'SE' THEN 'Southeast'
        END,
  fdsuf=CASE fdsuf
        WHEN 'N' THEN 'North'
        WHEN 'S' THEN 'South'
        WHEN 'E' THEN 'East'
        WHEN 'W' Then 'West'
        WHEN 'NW' THEN 'Northwest'
        WHEN 'SW' THEN 'Southwest'
        WHEN 'NE' THEN 'Northeast'
        WHEN 'SE' THEN 'Southeast'
        WHEN 'SB' THEN 'Southbound'
        WHEN 'NB' THEN 'Northbound'
        END,
  ftype=CASE ftype
        WHEN 'BRG' THEN 'Bridge'
        WHEN 'CR' THEN 'Creek'
        WHEN 'FWY' THEN 'Freeway'
        WHEN 'LOOP' THEN 'Loop'
        WHEN 'PARK' THEN 'Park'
        WHEN 'RDG' THEN 'Ridge'
        WHEN 'PT' THEN 'Point'
        WHEN 'ST' THEN 'Street'
        WHEN 'RD' THEN 'Road'
        WHEN 'PL' THEN 'Place'
        WHEN 'WAY' THEN 'Way'
        WHEN 'DR' THEN 'Drive'
        WHEN 'BLVD' THEN 'Boulevard'
        WHEN 'SQ' THEN 'Square'
        WHEN 'LN' THEN 'Lane'
        WHEN 'CT' THEN 'Court'
        WHEN 'TER' THEN 'Terrace'
        WHEN 'PKWY' THEN 'Parkway'
        WHEN 'CIR' THEN 'Circle'
        WHEN 'HWY' THEN 'Highway'
        WHEN 'AVE' THEN 'Avenue'
        WHEN 'CRES' THEN 'Crest'
        WHEN 'PATH' THEN 'Path'
        WHEN 'ALY' THEN 'Alley'
        WHEN 'WALK' THEN 'Walk'
        WHEN 'CRST' THEN 'Crescent'
        END;



-- CREATE  INDEX ON bldgs_2013_03_06 (bldg_id);
-- CREATE index on bldgs_2013_03_06 (tlid);
-- CREATE INDEX ON bldgs_2013_03_06 USING gist(centroid);
-- DELETE FROM bldgs_2013_03_06 WHERE bldg_id IS NULL;

-- SELECT min(gid) as gid, bldg_id,st_union(geom) as geom
-- INTO temp table foo
-- FROM bldgs_2013_03_06
--  GROUP by bldg_id
--  HAVING count(*) > 1;

-- UPDATE bldgs_2013_03_06
--   SET geom=foo.geom
--   FROM foo
--   WHERE bldgs_2013_03_06.bldg_id=foo.bldg_id;

-- DELETE from bldgs_2013_03_06
--  WHERE bldg_id IN (select bldg_id from foo)
--  AND  gid NOT IN (select gid from foo);
-- ;

-- CREATE UNIQUE INDEX ON bldgs_2013_03_06 (bldg_id);

DROP TABLE IF EXISTS pdx_addrs;

CREATE TABLE pdx_addrs AS
 SELECT distinct on (tlid,housenumber,street,postcode)
  tlid,
  house as housenumber,
  array_to_string(ARRAY[a.fdpre,a.fname,a.ftype,a.fdsuf],' ') as street,
  nbo_hood.name as neighborhood,
  a.zip as postcode,
  initcap(a.juris_city) as city,
  'OR'::varchar(2) as state,
  'US'::varchar(2) as country,
  st_transform(a.geom,4326)::geometry(Point,4326) as geom
FROM master_address a
LEFT OUTER JOIN nbo_hood on st_intersects(nbo_hood.geom,a.geom);
CREATE INDEX ON pdx_addrs (tlid);
CREATE INDEX ON pdx_addrs using gist(geom);

DROP TABLE  IF EXISTS pdx_bldgs;

CREATE table pdx_bldgs as 
SELECT  b.bldg_id,
  b.tlid,
  b.num_story as levels,
  round(b.surf_elev * 0.3048,2) as ele,
  round(b.max_height * 0.3048,2) as height,
  b.bldg_name as name,
  'yes'::varchar(20) as building,
  b.bldg_use,
  0::integer as no_addrs,
  st_transform(b.geom,4326)::geometry(MultiPolygon,4326) as geom
FROM bldgs_2013_03_06 b;


CREATE UNIQUE INDEX ON pdx_bldgs (bldg_id);
CREATE INDEX ON pdx_bldgs (tlid);
CREATE INDEX ON pdx_bldgs (bldg_use);
CREATE INDEX ON pdx_bldgs USING gist(geom);

UPDATE pdx_bldgs b
  SET no_addrs=count
  FROM (SELECT count(*),tlid from pdx_addrs group by tlid) a
  WHERE b.tlid=a.tlid;

DELETE FROM pdx_bldgs
  USING planet_osm_polygon
WHERE st_intersects(geom,st_transform(way,4326));

select * from bldgs_2013_03_06 b
LEFT OUTER JOIN pdx_bldgs p ON p.bldg_id=b.bldg_id
WHERE p.bldg_id IS NULL;

