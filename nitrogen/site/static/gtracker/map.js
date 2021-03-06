var Map = {
   projection: new OpenLayers.Projection("EPSG:900913"),
   displayProjection:  new OpenLayers.Projection("EPSG:4326"),

   // create map
   create:  function($element_id) {
               var $options = {
                  projection: Map.projection,
                  displayProjection: Map.displayProjection,
                  units: "m",
                  maxResolution: 156543.0339,
                  maxExtent: new OpenLayers.Bounds(-20037508.34, -20037508.34,
                        20037508.34, 20037508.34),
                  controls: []
               };

               var $map = new OpenLayers.Map($element_id, $options); 

               $map.addLayers([
                  new OpenLayers.Layer.OSM("OSM Mapnik"),
                  new OpenLayers.Layer.OSM.CycleMap("OSM CycleMap"),
                  new OpenLayers.Layer.OSM.Osmarender("OSM Osmarender"),
                  new OpenLayers.Layer.Google("Google Maps", { sphericalMercator: true })
               ]);

               $map.addControl(new OpenLayers.Control.LayerSwitcher());
               $map.addControl(new OpenLayers.Control.Navigation());
               $map.addControl(new OpenLayers.Control.ZoomPanel());
               $map.addControl(new OpenLayers.Control.PanPanel());

               return $map;
            },

   track:   function($options) {
               var $opts = OpenLayers.Util.extend({ color: "#000000", width: 6, name: "No Name", opacity: 0.7 }, $options);
               var $layer_style = OpenLayers.Util.extend(OpenLayers.Feature.Vector.style['default'], { fillOpacity: 0.2, graphicOpacity: 1 });
               $layer_style.fillOpacity = 0.2;
               $layer_style.graphicOpacity = 1;

               var $line_style = {
                  strokeColor: $opts.color,
                  strokeWidth: $opts.width,
                  pointRadius: $opts.width,
                  strokeOpacity: $opts.opacity,
                  pointerEvents: "visiblePainted"
               };

               var $vector = new OpenLayers.Layer.Vector($opts.name, {style: $layer_style})
               var $geometry = new OpenLayers.Geometry.LineString([]);
               $vector.addFeatures([ new OpenLayers.Feature.Vector($geometry, null, $line_style) ]);


               return {
                  layer: $vector,
                  geometry: $geometry,
                  append: function($lon, $lat) {
                     this.geometry.addPoint(Map.p($lon, $lat));
                  },
                  update: function() {
                     this.layer.redraw();
                  },
                  last: function() {
                     if (this.geometry.components.length != 0) {
                        var $point = this.geometry.components[this.geometry.components.length - 1];
                        return new OpenLayers.LonLat($point.x, $point.y);
                     }

                     return undefined;
                  }
               };
            },

   // create LatLon
   ll:      function($lon, $lat) {
               return new OpenLayers.LonLat($lon, $lat).transform(Map.displayProjection, Map.projection);
            },

   // create poin
   p:       function($lon, $lat) {
               return new OpenLayers.Geometry.Point($lon, $lat).transform(Map.displayProjection, Map.projection);
            }
}
