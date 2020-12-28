provide  {
    geo-chart: geo-chart,
    render-chart: render-chart,
    render-charts: render-charts,
    from-list: from-list,
} end

provide-types {
  Plot :: Plot,
  PlotOptions :: WrappedPlotOptions,
  PlotWindowOptions :: WrappedPlotWindowOptions,
  DataSeries :: DataSeries,
  ChartWindow :: ChartWindow,
}

import global as G
import base as B
include option
import image-structs as I
import internal-image-untyped as IM
import chart-lib as CI
import plot-lib as P
import plot-lib-list as PL
import either as E
import string-dict as SD
import valueskeleton as VS
import statistics as ST


#plot-list

data Series:
  | geo-map-series(labels :: List<String>, values :: List<Number>, threshold :: List<Number>) 
    with: typ: 'geo-map'
end

type PlotObject = {
  _title :: String,
  _extend-x :: Number,
  _extend-y :: Number,
  #_x-axis :: String,
  #_y-axis :: String,
  #_x-min :: Number,
  #_x-max :: Number,
  #_y-min :: Number,
  #_y-max :: Number,
  #_num-samples :: Number,
  #_infer-bounds :: Boolean,

  # methods (use Any as type synonyms don't allow recursive types)
  x-axis :: (String -> Any),
  y-axis :: (String -> Any),
  x-min :: (Number -> Any),
  x-max :: (Number -> Any),
  y-min :: (Number -> Any),
  y-max :: (Number -> Any),
  num-samples :: (Number -> Any),
  infer-bounds :: (Boolean -> Any),

  _render :: ( -> IM.Image),

  display :: ( -> IM.Image),
  get-image :: ( -> IM.Image),

  _output :: ( -> VS.ValueSkeleton)
}

fun check-plot-object(p :: PlotObject) -> Nothing block:
  when (p._extend-x < 0) or (p._extend-x > 1):
    raise('plot: extend-x must be between 0 and 1')
  end
  when (p._extend-y < 0) or (p._extend-y > 1):
    raise('plot: extend-y must be between 0 and 1')
  end
  nothing
end

plot-object-base :: PlotObject = {
  _series: empty,
  _title: '',
  _extend-x: 0,
  _extend-y: 0,
  method title(self, title :: String):
    self.{_title: title}
  end,
  method extend-x(self, extend-x :: Number):
    self.{_extend-x: extend-x}
  end,
  method extend-y(self, extend-y :: Number):
    self.{_extend-y: extend-y}
  end,

  # OPERATION NOT SUPPORTED (UNLESS OVERRIDDEN)

  method x-axis(self, x-axis :: String):
    raise("x-axis: operation not supported")
  end,
  method y-axis(self, y-axis :: String):
    raise("y-axis: operation not supported")
  end,
  method x-min(self, x-min :: Number):
    raise("x-min: operation not supported")
  end,
  method x-max(self, x-max :: Number):
    raise("x-max: operation not supported")
  end,
  method y-min(self, y-min :: Number):
    raise("y-min: operation not supported")
  end,
  method y-max(self, y-max :: Number):
    raise("y-max: operation not supported")
  end,
  method num-samples(self, num-samples :: Number):
    raise("num-samples: operation not supported")
  end,
  method infer-bounds(self, infer-bounds :: Boolean):
    raise("infer-bounds: operation not supported")
  end,

  method display(self):
    _ = check-plot-object(self)
    self.{_interact: true}._render()
  end,
  method get-image(self):
    _ = check-plot-object(self)
    self.{_interact: false}._render()
  end,
  method _output(self) -> VS.ValueSkeleton:
    VS.vs-constr("plot-object", [list: VS.vs-str("...")])
  end,

  method _render(self):
    raise("render: this should not happen")
  end
}

plot-object-axis :: PlotObject = plot-object-base.{
  _x-axis: '',
  _y-axis: '',
  method x-axis(self, x-axis :: String):
    self.{_x-axis: x-axis}
  end,
  method y-axis(self, y-axis :: String):
    self.{_y-axis: y-axis}
  end,
}

plot-object-xy :: PlotObject = plot-object-axis.{
  _x-min: -10,
  _x-max: 10,
  _y-min: -10,
  _y-max: 10,
  _num-samples: 1000,
  _infer-bounds: true,

  method x-min(self, x-min :: Number):
    self.{_x-min: x-min, _infer-bounds: false}
  end,
  method x-max(self, x-max :: Number):
    self.{_x-max: x-max, _infer-bounds: false}
  end,
  method y-min(self, y-min :: Number):
    self.{_y-min: y-min, _infer-bounds: false}
  end,
  method y-max(self, y-max :: Number):
    self.{_y-max: y-max, _infer-bounds: false}
  end,
  method num-samples(self, num-samples :: Number) block:
    when (num-samples <= 0) or (num-samples > 100000):
      raise("num-samples: value must be between 1 and 100000")
    end
    self.{_num-samples: num-samples}
  end,
  method infer-bounds(self, infer-bounds :: Boolean):
    self.{_infer-bounds: infer-bounds}
  end
}

fun adjustable-geo-map(labels :: List<String>, values :: List<Number>, radiuses :: List<Number>) 
  -> Series block:
  label-length = labels.length()
  value-length = values.length()
  when label-length <> value-length:
    raise('adjustable-geo-chart: labels and values should have the same length')
  end
  radius-length = radiuses.length()
  when label-length <> radius-length:
    raise('adjustable-geo-chart: labels and radiuses should have the same length')
  end
  when label-length == 0:
    raise('adjustable-geo-chart: need at least one data')
  end
  geo-map-series(labels, values, radiuses)
end

fun geo-map-s(labels :: List<String>, values :: List<Number>) -> Series block:
  doc: ```
       Consume labels, a list of string, and values, a list of numbers
       and construct a geo chart   ```
  label-length = labels.length()
  value-length = values.length()
  when label-length <> value-length:
    raise('geo-chart: labels and values should have the same length')
  end
  when label-length == 0:
    raise('geo-chart: need at least one data')
  end
  geo-map-series(labels, values, repeat(label-length, 1))
end

fun plot(s :: Series) -> PlotObject:
  doc: "plots a geo-map"
  cases (Series) s:
    | geo-map-series(labels, values, threshold) =>
      plot-object-base.{
        method _render(self):
          geo-map-s(self, map3(
              {(l :: String, v :: Number, t :: Number): [raw-array: l, v, t]},
              labels,
              values,
              threshold) ^ builtins.raw-array-from-list)
        end
      }
  end
end

#plot

type BaseWindowOptions = {
  extend-x :: Number,
  extend-y :: Number,
  interact :: Boolean,
  title :: String
}

base-window-options :: BaseWindowOptions = {
  extend-x: 0,
  extend-y: 0,
  interact: true,
  title: ''
}

type GeoChartWindowOptions = BaseWindowOptions
geo-chart-window-option :: GeoChartWindowOptions = base-window-options

type WrappedGeoChartWindowOptions = (GeoChartWindowOptions -> GeoChartWindowOptions)

fun check-base-window-options(options :: BaseWindowOptions) -> Nothing block:
  when (options.extend-x < 0) or (options.extend-x > 1):
    raise('plot: extend-x must be between 0 and 1')
  end
  when (options.extend-y < 0) or (options.extend-y > 1):
    raise('plot: extend-y must be between 0 and 1')
  end
  nothing
end

fun geo-map(tab :: Table, options-generator :: WrappedGeoChartWindowOptions) -> IM.Image block:
  doc: 'Consume a table with two columns: `region` and `value`, and show a geo-map'
  when not(tab._header-raw-array =~ [raw-array: 'region', 'value']):
    raise('geo-map: expect a table with columns named `region` and `value`')
  end
  when raw-array-length(tab._rows-raw-array) == 0:
    raise('geo-map: expect the table to have at least one row')
  end
  #return rendered map
end

#charts: 

################################################################################
# DEFAULT VALUES
################################################################################
type ChartWindowObject = {
  title :: String,
  width :: Number,
  height :: Number,
  render :: ( -> IM.Image)
}

default-chart-window-object :: ChartWindowObject = {
  title: '',
  width: 800,
  height: 600,
  method render(self): raise('unimplemented') end,
}

type GeoChartWindowObject = {
  title :: String,
  width :: Number,
  height :: Number,
  render :: ( -> IM.Image),
}

default-geo-chart-window-object :: GeoChartWindowObject = default-chart-window-object

type TableIntern<A> = RawArray<RawArray<A>>

type GeoChartSeries = {
  tab :: TableIntern,
}

default-geochart-series = {}


################################################################################
# HELPERS
################################################################################
fun check-num(v :: Number) -> Nothing: nothing end
fun check-string(v :: String) -> Nothing: nothing end

fun to-table2(xs :: List<Any>, ys :: List<Any>) -> TableIntern:
  map2({(x, y): [raw-array: x, y]}, xs, ys) ^ builtins.raw-array-from-list
end

fun get-vs-from-img(s :: String, raw-img :: IM.Image) -> VS.ValueSkeleton:
  I.color(190, 190, 190, 0.75)
    ^ IM.text-font(s, 72, _, "", "modern", "normal", "bold", false)
    ^ IM.overlay-align("center", "bottom", _, raw-img)
    ^ VS.vs-value
end

fun check-chart-window(p :: ChartWindowObject) -> Nothing:
  if (p.width <= 0) or (p.height <= 0):
    raise('render: width and height must be positive')
  else:
    nothing
  end
end

################################################################################
# DATA DEFINITIONS
################################################################################
data ChartWindow:
  | geochart-window(obj :: GeoChartWindowObject) with:
    constr: {(): geochart-window},
sharing:
  method display(self):
    _ = check-chart-window(self.obj)
    self.obj.{interact: true}.render()
  end,
  method get-image(self):
    _ = check-chart-window(self.obj)
    self.obj.{interact: false}.render()
  end,
  method title(self, title :: String):
    self.constr()(self.obj.{title: title})
  end,
  method width(self, width :: Number):
    self.constr()(self.obj.{width: width})
  end,
  method height(self, height :: Number):
    self.constr()(self.obj.{height: height})
  end,
  method _output(self):
    get-vs-from-img("ChartWindow", self.get-image())
  end
end

data DataSeries:
  | geochart-series(obj :: GeoChartSeries) with:
    is-single: true,
    contr: {(): geochart-series},
sharing:
  method _output(self):
    get-vs-from-img("DataSeries", render-chart(self).get-image())
  end
end

################################################################################
# FUNCTIONS
################################################################################
#This data definition of DataSeries and the function, render-chart, is meant to be added
#as a part of the ones in blob/horizon/src/web/arr/trove/chart.arr
fun render-chart(s :: DataSeries) -> ChartWindow:
  doc: "Render it!"
  cases(DataSeries) s:
    |geochart-series(obj) =>
      default-geo-chart-window-object.{
        method render(self):
        geo-map(self, obj) end
      } ^ geochart-window
  end
end

fun geochart-from-list(
    region-labels :: List<String>,
    values :: List<Number>) -> DataSeries block:
  region-length = region-labels.length()
  values-length = values.length()
  when region-length <> values-length:
    raise("geochart: region-labels and values should have the same length")
  end
  values.each(check-num)
  region-labels.each(check-string)
  default-geochart-series.{
    tab: to-table2(region-labels, values)
  } ^ geochart-series
end

