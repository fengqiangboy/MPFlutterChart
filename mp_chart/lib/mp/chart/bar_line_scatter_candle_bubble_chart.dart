import 'package:flutter/widgets.dart';
import 'package:mp_chart/mp/chart/chart.dart';
import 'package:mp_chart/mp/chart/horizontal_bar_chart.dart';
import 'package:mp_chart/mp/controller/bar_line_scatter_candle_bubble_controller.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_data_set.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/highlight_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/painter/bar_line_chart_painter.dart';

abstract class BarLineScatterCandleBubbleChart<
    P extends BarLineChartBasePainter,
    C extends BarLineScatterCandleBubbleController> extends Chart<P, C> {
  BarLineScatterCandleBubbleChart(C controller) : super(controller);

  @override
  void doneBeforePainterInit() {
    super.doneBeforePainterInit();
    controller.gridBackgroundPaint = Paint()
      ..color = controller.gridBackColor == null
          ? Color.fromARGB(255, 240, 240, 240)
          : controller.gridBackColor
      ..style = PaintingStyle.fill;

    controller.borderPaint = Paint()
      ..color = controller.borderColor == null
          ? ColorUtils.BLACK
          : controller.borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = Utils.convertDpToPixel(controller.borderStrokeWidth);

    controller.drawListener ??= controller.initDrawListener();
    controller.axisLeft = controller.initAxisLeft();
    controller.axisRight = controller.initAxisRight();
    controller.leftAxisTransformer ??= controller.initLeftAxisTransformer();
    controller.rightAxisTransformer ??= controller.initRightAxisTransformer();
    controller.zoomMatrixBuffer ??= controller.initZoomMatrixBuffer();
    controller.axisRendererLeft = controller.initAxisRendererLeft();
    controller.axisRendererRight = controller.initAxisRendererRight();
    controller.xAxisRenderer = controller.initXAxisRenderer();
    if (controller.axisLeftSettingFunction != null) {
      controller.axisLeftSettingFunction(controller.axisLeft, this);
    }
    if (controller.axisRightSettingFunction != null) {
      controller.axisRightSettingFunction(controller.axisRight, this);
    }
  }

  BarLineChartBasePainter get painter => super.painter;

  void setViewPortOffsets(final double left, final double top,
      final double right, final double bottom) {
    controller.customViewPortEnabled = true;
    controller.viewPortHandler.restrainViewPort(left, top, right, bottom);
  }
}

abstract class BarLineScatterCandleBubbleState<
    T extends BarLineScatterCandleBubbleChart> extends ChartState<T> {
  IDataSet _closestDataSetToTouch;

  Highlight lastHighlighted;
  double _curX = 0.0;
  double _curY = 0.0;
  double _scaleX = -1.0;
  double _scaleY = -1.0;
  bool _isZoom = false;

  MPPointF _getTrans(double x, double y) {
    ViewPortHandler vph = widget.painter.viewPortHandler;

    double xTrans = x - vph.offsetLeft();
    double yTrans = 0.0;

    // check if axis is inverted
    if (_inverted()) {
      yTrans = -(y - vph.offsetTop());
    } else {
      yTrans = -(widget.painter.getMeasuredHeight() - y - vph.offsetBottom());
    }

    return MPPointF.getInstance1(xTrans, yTrans);
  }

  bool _inverted() {
    var res = (_closestDataSetToTouch == null &&
            widget.painter.isAnyAxisInverted()) ||
        (_closestDataSetToTouch != null &&
            widget.painter
                .isInverted(_closestDataSetToTouch.getAxisDependency()));
    return res;
  }

  @override
  void onTapDown(TapDownDetails detail) {
    _curX = detail.localPosition.dx;
    _curY = detail.localPosition.dy;
    _closestDataSetToTouch = widget.painter.getDataSetByTouchPoint(
        detail.localPosition.dx, detail.localPosition.dy);
  }

  @override
  void onDoubleTap() {
    if (widget.painter.doubleTapToZoomEnabled &&
        widget.painter.getData().getEntryCount() > 0) {
      MPPointF trans = _getTrans(_curX, _curY);
      widget.painter.zoom(widget.painter.scaleXEnabled ? 1.4 : 1,
          widget.painter.scaleYEnabled ? 1.4 : 1, trans.x, trans.y);
//      painter.getOnChartGestureListener()?.onChartDoubleTapped(_curX, _curY);
      setStateIfNotDispose();
      MPPointF.recycleInstance(trans);
    }
  }

  @override
  void onScaleEnd(ScaleEndDetails detail) {
    if (_isZoom) {
      _isZoom = false;
    }
    _scaleX = -1.0;
    _scaleY = -1.0;
  }

  @override
  void onScaleStart(ScaleStartDetails detail) {
    _curX = detail.localFocalPoint.dx;
    _curY = detail.localFocalPoint.dy;
  }

  @override
  void onScaleUpdate(ScaleUpdateDetails detail) {
    if (_scaleX == -1.0 && _scaleY == -1.0) {
      _scaleX = detail.horizontalScale;
      _scaleY = detail.verticalScale;
      return;
    }

//    OnChartGestureListener listener = painter.getOnChartGestureListener();
    if (_scaleX == detail.horizontalScale && _scaleY == detail.verticalScale) {
      if (_isZoom) {
        return;
      }

      var dx = detail.localFocalPoint.dx - _curX;
      var dy = detail.localFocalPoint.dy - _curY;
      if (widget.painter.dragYEnabled && widget.painter.dragXEnabled) {
        if (_inverted()) {
          // if there is an inverted horizontalbarchart
          if (widget is HorizontalBarChart) {
            dx = -dx;
          } else {
            dy = -dy;
          }
        }
        widget.painter.translate(dx, dy);
        _dragHighlight(
            Offset(detail.localFocalPoint.dx, detail.localFocalPoint.dy));
//        listener?.onChartTranslate(
//            detail.localFocalPoint.dx, detail.localFocalPoint.dy, dx, dy);
        setStateIfNotDispose();
      } else {
        if (widget.painter.dragXEnabled) {
          if (_inverted()) {
            // if there is an inverted horizontalbarchart
            if (widget is HorizontalBarChart) {
              dx = -dx;
            } else {
              dy = -dy;
            }
          }
          widget.painter.translate(dx, 0.0);
          _dragHighlight(Offset(detail.localFocalPoint.dx, 0.0));
//          listener?.onChartTranslate(
//              detail.localFocalPoint.dx, detail.localFocalPoint.dy, dx, dy);
          setStateIfNotDispose();
        } else if (widget.painter.dragYEnabled) {
          if (_inverted()) {
            // if there is an inverted horizontalbarchart
            if (widget is HorizontalBarChart) {
              dx = -dx;
            } else {
              dy = -dy;
            }
          }
          widget.painter.translate(0.0, dy);
          _dragHighlight(Offset(0.0, detail.localFocalPoint.dy));
//          listener?.onChartTranslate(
//              detail.localFocalPoint.dx, detail.localFocalPoint.dy, dx, dy);
          setStateIfNotDispose();
        }
      }
      _curX = detail.localFocalPoint.dx;
      _curY = detail.localFocalPoint.dy;
    } else {
      var scaleX = detail.horizontalScale / _scaleX;
      var scaleY = detail.verticalScale / _scaleY;

      if (!_isZoom) {
        scaleX = detail.horizontalScale;
        scaleY = detail.verticalScale;
        _isZoom = true;
      }

      MPPointF trans = _getTrans(_curX, _curY);

      var h = widget.painter.viewPortHandler;
      bool canZoomMoreX = false;
      bool canZoomMoreY = false;
      if (h != null) {
        canZoomMoreX = scaleX < 1 ? h.canZoomOutMoreX() : h.canZoomInMoreX();
        canZoomMoreY = scaleY < 1 ? h.canZoomOutMoreY() : h.canZoomInMoreY();
      }

      scaleX = (widget.painter.scaleXEnabled && canZoomMoreX) ? scaleX : 1.0;
      scaleY = (widget.painter.scaleYEnabled && canZoomMoreY) ? scaleY : 1.0;

      if (canZoomMoreX && canZoomMoreY) {
        widget.painter.zoom(scaleX, scaleY, trans.x, trans.y);
//      listener?.onChartScale(
//          detail.localFocalPoint.dx, detail.localFocalPoint.dy, scaleX, scaleY);
        setStateIfNotDispose();
      } else {
        if (canZoomMoreX) {
          widget.painter.zoom(scaleX, 1.0, trans.x, trans.y);
          setStateIfNotDispose();
        }
        if (canZoomMoreY) {
          widget.painter.zoom(1.0, scaleY, trans.x, trans.y);
          setStateIfNotDispose();
        }
      }
      MPPointF.recycleInstance(trans);
    }
    _scaleX = detail.horizontalScale;
    _scaleY = detail.verticalScale;
    _curX = detail.localFocalPoint.dx;
    _curY = detail.localFocalPoint.dy;
  }

  void _dragHighlight(Offset offset) {
    if (widget.painter.highlightPerDragEnabled) {
      Highlight h =
          widget.painter.getHighlightByTouchPoint(offset.dx, offset.dy);
      if (h != null && !h.equalTo(lastHighlighted)) {
        lastHighlighted = h;
        widget.painter.highlightValue6(h, true);
      }
    } else {
      lastHighlighted = null;
    }
  }

  @override
  void onSingleTapUp(TapUpDetails detail) {
    if (widget.painter.highLightPerTapEnabled) {
      Highlight h = widget.painter.getHighlightByTouchPoint(
          detail.localPosition.dx, detail.localPosition.dy);
      lastHighlighted =
          HighlightUtils.performHighlight(widget.painter, h, lastHighlighted);
//      painter.getOnChartGestureListener()?.onChartSingleTapped(
//          detail.localPosition.dx, detail.localPosition.dy);
      setStateIfNotDispose();
    } else {
      lastHighlighted = null;
    }
  }
}
