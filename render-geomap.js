({
    requires: [
        { 'import-type': 'builtin', 'name': 'image-lib' },
    ],
    nativeRequires: [
        'pyret-base/js/js-numbers',
        'google-charts',
    ],
    provides: {
        values: {
            'pie-chart': "tany",
            'bar-chart': "tany",
            'histogram': "tany",
            'box-plot': "tany",
            'plot': "tany"
        }
    },
    theModule: function (RUNTIME, NAMESPACE, uri, IMAGELIB, jsnums , google) {
        'use strict';

        // Load google library via editor.html to avoid loading issues

        //const google = _google.google;
        const isTrue = RUNTIME.isPyretTrue;
        const get = RUNTIME.getField;
        const toFixnum = jsnums.toFixnum;
        const cases = RUNTIME.ffi.cases;

        var IMAGE = get(IMAGELIB, "internal");

        google.charts.load('current', {'packages' : ['corechart']});

        //////////////////////////////////////////////////////////////////////////////

        function getPrettyNumToStringDigits(d) {
            // this accepts Pyret num
            return n =>
                jsnums.toStringDigits(n, d, RUNTIME.NumberErrbacks).replace(/\.?0*$/, '');
        }

        const prettyNumToStringDigits5 = getPrettyNumToStringDigits(5);

        function convertColor(v) {
            function p(pred, name) {
                return val => {
                    RUNTIME.makeCheckType(pred, name)(val);
                    return val;
                };
            }

            const colorDb = IMAGE.colorDb;
            const _checkColor = p(IMAGE.isColorOrColorString, 'Color');

            function checkColor(val) {
                let aColor = _checkColor(val);
                if (colorDb.get(aColor)) {
                    aColor = colorDb.get(aColor);
                }
                return aColor;
            }

            function rgb2hex(rgb){
                // From http://jsfiddle.net/Mottie/xcqpF/1/light/
                rgb = rgb.match(/^rgba?[\s+]?\([\s+]?(\d+)[\s+]?,[\s+]?(\d+)[\s+]?,[\s+]?(\d+)[\s+]?/i);
                return (rgb && rgb.length === 4) ? "#" +
                    ("0" + parseInt(rgb[1],10).toString(16)).slice(-2) +
                    ("0" + parseInt(rgb[2],10).toString(16)).slice(-2) +
                    ("0" + parseInt(rgb[3],10).toString(16)).slice(-2) : '';
            }
            return rgb2hex(IMAGE.colorString(checkColor(v)));
        }

        //////////////////////////////////////////////////////////////////////////////

        function geoChart(globalOptions, rawData) {
            const table = get(rawData, 'tab');
            const data = new google.visualization.GeoMap;
            return {
                data: data,
                options: {
                    slices: table.map(row => ({offset: toFixnum(row[2])})),
                    legend: {
                        alignment: 'end'
                    }
                },
                chartType: google.visualization.GeoMap,
                onExit: defaultImageReturn,
            }
        }

            //////////////////////////////////////////////////////////////////////////////


            function onExitRetry(resultGetter, restarter) {
                const result = resultGetter();
                if (result !== null) {
                    result.onExit(restarter, result);
                } else {
                    setTimeout(onExitRetry, 100, resultGetter, restarter);
                }
            }


            function imageReturn(url, restarter, hook) {
                const rawImage = new Image();
                rawImage.onload = () => {
                    restarter.resume(
                        hook(
                            RUNTIME.makeOpaque(
                                IMAGE.makeFileImage(url, rawImage),
                                IMAGE.imageEquals
                            )
                        )
                    );
                };
                rawImage.onerror = e => {
                    restarter.error(
                        RUNTIME.ffi.makeMessageException(
                            'unable to load the image: ' + e.message));
                };
                rawImage.src = url;
            }

            function defaultImageReturn(restarter, result) {
                /*
                We in fact should put imageReturn(...) inside
                google.visualization.events.addListener(result.chart, 'ready', () => {
                  ...
                });
                However, somehow this event is never triggered, so we will just call
                it here to guarantee that it will return.
                */
                imageReturn(result.chart.getImageURI(), restarter, x => x);
            }

            function makeFunction(f) {
                return RUNTIME.makeFunction((globalOptions, rawData) => {
                    const root = $('<div/>');
                    const overlay = $('<div/>', {style: 'position: absolute'});
                    const isInteractive = isTrue(get(globalOptions, 'interact'));

                    let result = null;

                    function draw(optMutator) {
                        optMutator = optMutator ? optMutator : x => x;
                        if (result != null) {
                            result.chart.draw(result.data, optMutator(result.options));
                        }
                    }

                    function setup(restarter) {
                        const tmp = f(globalOptions, rawData);
                        tmp.chart = new tmp.chartType(root[0]);
                        const options = {
                            backgroundColor: {fill: 'transparent'},
                            title: get(globalOptions, 'title'),
                        };

                        if ('mutators' in tmp) {
                            tmp.mutators.forEach(fn => fn(options, globalOptions, rawData));
                        }

                        tmp.options = $.extend({}, options, 'options' in tmp ? tmp.options : {});

                        if ('overlay' in tmp) tmp.overlay(overlay, restarter, tmp.chart, root);

                        // only mutate result when everything is setup
                        result = tmp;
                        // this draw will have a wrong width / height, but do it for now so
                        // that overlay works
                        draw();
                        // must append the overlay _after_ drawing to make the overlay appear
                        // correctly
                        root.append(overlay);
                    }

                    return RUNTIME.pauseStack(restarter => {
                        google.charts.setOnLoadCallback(() => {
                            setup(restarter);
                            RUNTIME.getParam('chart-port')({
                                root: root[0],
                                onExit: () => onExitRetry(() => result, restarter),
                                draw: draw,
                                windowOptions: {
                                    width: toFixnum(get(globalOptions, 'width')),
                                    height: toFixnum(get(globalOptions, 'height'))
                                },
                                isInteractive: isInteractive,
                                getImageURI: () => result.chart.getImageURI(),
                                // thunk it here b/c apparently getImageURI is going to be mutated
                                // by Google
                            });
                        });
                    });
                });
            }

            return RUNTIME.makeObject({
                'provide-plus-types': RUNTIME.makeObject({
                    types: RUNTIME.makeObject({}),
                    values: RUNTIME.makeObject({
                        'pie-chart': makeFunction(pieChart),
                        'bar-chart': makeFunction(barChart),
                        'histogram': makeFunction(histogram),
                        'box-plot': makeFunction(boxPlot),
                        'plot': makeFunction(plot),
                    })
                })
            });
        }
    })
