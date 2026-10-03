import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:viernes/app/theme/liquid_palette.dart';

// Piezas del diseño Liquid: fondo de luz ambiental, vidrio (aproximación del
// Liquid Glass de Apple con desenfoque, borde y brillo), presión con resorte,
// deslizar para confirmar y el orbe de voz.

/// Marca que ya hay un fondo ambiental más arriba (no se dibuja dos veces).
class _AmbientScope extends InheritedWidget {
  const _AmbientScope({required super.child});

  static bool has(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_AmbientScope>() != null;

  @override
  bool updateShouldNotify(_AmbientScope oldWidget) => false;
}

/// Tono de la luz de fondo según la pantalla.
enum AmbientMood {
  /// Cobalto y brasa (lo normal).
  calm,

  /// Más brasa: alertas y lo urgente.
  alert,

  /// Más acento: la conversación con Viernes.
  voice,
}

/// Fondo grafito con manchas de luz que se mueven despacio. El vidrio de
/// encima las refracta. Sin animación si el usuario la desactivó.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({
    required this.child,
    this.mood = AmbientMood.calm,
    super.key,
  });

  final Widget child;
  final AmbientMood mood;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      unawaited(_drift.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = LiquidPalette.of(context);
    return _AmbientScope(
      child: ColoredBox(
        color: p.ink,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _drift,
                builder: (context, _) => CustomPaint(
                  painter: _AmbientPainter(
                    t: Curves.easeInOut.transform(_drift.value),
                    palette: p,
                    mood: widget.mood,
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.t, required this.palette, required this.mood});

  final double t;
  final LiquidPalette palette;
  final AmbientMood mood;

  void _blob(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity * palette.ambientStrength),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final a = t * math.pi;
    final (warm, cool, accent) = switch (mood) {
      AmbientMood.calm => (0.42, 0.5, 0.1),
      AmbientMood.alert => (0.7, 0.3, 0.06),
      AmbientMood.voice => (0.2, 0.38, 0.32),
    };
    _blob(
      canvas,
      Offset(w * (0.05 + 0.12 * math.sin(a)), h * (0.18 + 0.06 * math.cos(a))),
      w * 0.85,
      palette.ember,
      warm,
    );
    _blob(
      canvas,
      Offset(w * (1.0 - 0.1 * math.cos(a)), h * (0.55 + 0.08 * math.sin(a))),
      w * 1.0,
      palette.cobalt,
      cool,
    );
    _blob(
      canvas,
      Offset(w * (0.4 + 0.15 * math.cos(a * 1.3)), h * (0.92 - 0.05 * t)),
      w * 0.7,
      palette.accent,
      accent,
    );
  }

  @override
  bool shouldRepaint(_AmbientPainter old) =>
      old.t != t || old.palette != palette || old.mood != mood;
}

/// Vidrio líquido: desenfoca lo de atrás, lo satura un poco y le pone borde
/// con brillo arriba (la luz que lo atraviesa).
///
/// Con [blur] en falso es vidrio «quieto» (sin desenfoque real): más barato,
/// para listas largas.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    required this.child,
    this.radius = LiquidRadius.md,
    this.blur = true,
    this.padding,
    this.tint,
    this.shape = BoxShape.rectangle,
    super.key,
  });

  final Widget child;
  final double radius;
  final bool blur;
  final EdgeInsetsGeometry? padding;

  /// Color extra del vidrio (p. ej. acento translúcido).
  final Color? tint;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final p = LiquidPalette.of(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final borderRadius = shape == BoxShape.circle
        ? null
        : BorderRadius.circular(radius);
    final fill = tint ?? p.glassFill;
    final decoration = BoxDecoration(
      shape: shape,
      borderRadius: borderRadius,
      color: highContrast ? p.inkRaised : null,
      gradient: highContrast
          ? null
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(p.text.withValues(alpha: 0.1), fill),
                fill,
              ],
            ),
      border: Border.all(
        color: highContrast ? p.textSecondary : p.glassBorder,
      ),
    );
    // Sin sombra: a través del vidrio translúcido se vería como una franja.
    // Brillo del borde superior y reflejo en la esquina.
    final shine = BoxDecoration(
      shape: shape,
      borderRadius: borderRadius,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0, 0.012, 0.18, 0.6],
        colors: [
          p.glassHighlight,
          p.glassHighlight.withValues(alpha: 0.1),
          p.glassHighlight.withValues(alpha: 0.04),
          Colors.transparent,
        ],
      ),
    );
    Widget content = DecoratedBox(
      decoration: decoration,
      child: DecoratedBox(
        decoration: shine,
        position: DecorationPosition.foreground,
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
    if (blur && !highContrast) {
      content = BackdropFilter(
        filter: ImageFilter.compose(
          outer: ColorFilter.matrix(_saturate(1.6)),
          inner: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        ),
        child: content,
      );
    }
    return shape == BoxShape.circle
        ? ClipOval(child: content)
        : ClipRRect(borderRadius: borderRadius!, child: content);
  }

  static List<double> _saturate(double s) {
    const r = 0.2126;
    const g = 0.7152;
    const b = 0.0722;
    final i = 1 - s;
    return [
      i * r + s, i * g, i * b, 0, 0, //
      i * r, i * g + s, i * b, 0, 0, //
      i * r, i * g, i * b + s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }
}

/// Respuesta física al tocar: se encoge apenas el dedo baja y vuelve con un
/// resorte al soltar (aunque se interrumpa a mitad).
class PressScale extends StatefulWidget {
  const PressScale({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.95,
    this.haptic = false,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  /// Vibración corta al confirmar (solo en acciones con peso).
  final bool haptic;
  final String? semanticLabel;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 22,
  );

  void _to(double target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = target;
      return;
    }
    unawaited(
      _c.animateWith(
        SpringSimulation(_spring, _c.value, target, _c.velocity),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: Listener(
        onPointerDown: enabled ? (_) => _to(widget.scale) : null,
        onPointerUp: enabled ? (_) => _to(1) : null,
        onPointerCancel: enabled ? (_) => _to(1) : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap == null
              ? null
              : () {
                  if (widget.haptic) unawaited(HapticFeedback.lightImpact());
                  widget.onTap!();
                },
          onLongPress: widget.onLongPress,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) =>
                Transform.scale(scale: _c.value, child: child),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Pantalla con fondo ambiental. Si ya hay uno más arriba (pestañas dentro
/// del contenedor principal), no lo repite.
class LiquidScaffold extends StatelessWidget {
  const LiquidScaffold({
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.mood = AmbientMood.calm,
    this.extendBodyBehindAppBar = false,
    super.key,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final AmbientMood mood;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );
    if (_AmbientScope.has(context)) return scaffold;
    return AmbientBackground(mood: mood, child: scaffold);
  }
}

/// Título grande de pantalla, alineado a la izquierda, con acciones en
/// vidrio a la derecha.
class LiquidHeader extends StatelessWidget {
  const LiquidHeader({
    required this.title,
    this.eyebrow,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(4, 8, 0, 16),
    super.key,
  });

  final String title;
  final String? eyebrow;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(eyebrow!, style: text.bodyMedium),
                  ),
                Text(title, style: text.headlineLarge),
              ],
            ),
          ),
          for (final action in actions)
            Padding(padding: const EdgeInsets.only(left: 8), child: action),
        ],
      ),
    );
  }
}

/// Botón redondo de vidrio con un ícono.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 46,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: PressScale(
        onTap: onPressed,
        semanticLabel: tooltip,
        scale: 0.9,
        child: SizedBox.square(
          dimension: size,
          child: LiquidGlass(
            shape: BoxShape.circle,
            child: Center(child: Icon(icon, size: 22)),
          ),
        ),
      ),
    );
  }
}

/// Grupo de filas sobre vidrio (ajustes, listas): separadores finos con
/// sangría, sin una tarjeta por fila.
class GlassGroup extends StatelessWidget {
  const GlassGroup({required this.children, this.blur = false, super.key});

  final List<Widget> children;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final p = LiquidPalette.of(context);
    return LiquidGlass(
      blur: blur,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 16,
                  color: p.hairline,
                ),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// «Desliza para…»: la perilla sigue al dedo 1:1, resiste en los bordes y
/// vuelve con resorte. Llama a [onConfirmed] si se suelta cerca del final.
class SwipeToConfirm extends StatefulWidget {
  const SwipeToConfirm({
    required this.label,
    required this.onConfirmed,
    this.confirmedLabel,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String? confirmedLabel;
  final Future<void> Function() onConfirmed;
  final bool enabled;

  @override
  State<SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<SwipeToConfirm>
    with SingleTickerProviderStateMixin {
  static const _height = 76.0;
  static const _knob = 64.0;
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 320,
    damping: 20,
  );

  late final AnimationController _x = AnimationController.unbounded(
    vsync: this,
  );
  double _max = 0;
  bool _done = false;

  /// Resistencia progresiva al pasarse del borde.
  static double _rubber(double over, double dim, [double c = 0.55]) =>
      (over * dim * c) / (dim + c * over.abs());

  void _onUpdate(DragUpdateDetails d) {
    if (_done || !widget.enabled) return;
    final raw = _x.value + d.delta.dx;
    _x.value = raw < 0
        ? _rubber(raw, _max)
        : raw > _max
        ? _max + _rubber(raw - _max, _max)
        : raw;
  }

  Future<void> _onEnd(DragEndDetails d) async {
    if (_done || !widget.enabled) return;
    final velocity = d.velocity.pixelsPerSecond.dx;
    // Proyección del impulso: un lanzamiento rápido cuenta aunque no llegue.
    final projected = _x.value + velocity * 0.12;
    final confirm = projected > _max * 0.82;
    final target = confirm ? _max : 0.0;
    unawaited(
      _x.animateWith(SpringSimulation(_spring, _x.value, target, velocity)),
    );
    if (!confirm) return;
    setState(() => _done = true);
    unawaited(HapticFeedback.mediumImpact());
    await widget.onConfirmed();
  }

  @override
  void dispose() {
    _x.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = LiquidPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.enabled && !_done
          ? () {
              setState(() => _done = true);
              unawaited(widget.onConfirmed());
            }
          : null,
      child: SizedBox(
        height: _height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _max = constraints.maxWidth - _knob - 12;
            return LiquidGlass(
              radius: _height / 2,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: _knob + 8, right: 16),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _x,
                        builder: (context, _) => Opacity(
                          opacity: _done
                              ? 1
                              : (1 - (_x.value / _max)).clamp(0.0, 1.0),
                          child: Text(
                            _done
                                ? widget.confirmedLabel ?? widget.label
                                : widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelLarge?.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _x,
                    builder: (context, child) => Positioned(
                      left: 6 + _x.value,
                      top: 6,
                      child: child!,
                    ),
                    child: GestureDetector(
                      onHorizontalDragUpdate: _onUpdate,
                      onHorizontalDragEnd: (d) => unawaited(_onEnd(d)),
                      child: Container(
                        width: _knob,
                        height: _knob,
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _done ? Icons.check_rounded : Icons.arrow_forward,
                          color: p.onAccent,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// El orbe de Viernes: núcleo iris que respira y ondas mientras escucha.
class VoiceOrb extends StatefulWidget {
  const VoiceOrb({
    this.size = 132,
    this.listening = false,
    this.thinking = false,
    this.color,
    super.key,
  });

  final double size;
  final bool listening;
  final bool thinking;

  /// Color del núcleo (por defecto, el acento).
  final Color? color;

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  void _sync() {
    final animate =
        (widget.listening || widget.thinking) &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && !_c.isAnimating) {
      unawaited(_c.repeat());
    } else if (!animate && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant VoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = LiquidPalette.of(context);
    final color = widget.color ?? p.accent;
    final core = widget.size * 0.47;
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final breathe = widget.listening
              ? 1 + 0.12 * math.sin(t * 2 * math.pi)
              : widget.thinking
              ? 1 + 0.05 * math.sin(t * 4 * math.pi)
              : 1.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              LiquidGlass(
                shape: BoxShape.circle,
                child: SizedBox.square(dimension: widget.size),
              ),
              if (widget.listening)
                for (final delay in [0.0, 0.33, 0.66])
                  _Ripple(
                    progress: (t + delay) % 1,
                    size: widget.size,
                    color: color,
                  ),
              Transform.scale(
                scale: breathe,
                child: Container(
                  width: core,
                  height: core,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.4),
                      colors: [
                        Color.lerp(color, Colors.white, 0.65)!,
                        color,
                        Color.lerp(color, Colors.black, 0.25)!,
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Ripple extends StatelessWidget {
  const _Ripple({
    required this.progress,
    required this.size,
    required this.color,
  });

  final double progress;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scale = 0.55 + progress * 0.95;
    return IgnorePointer(
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.4 * (1 - progress)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta pequeña en cápsula.
class LiquidTag extends StatelessWidget {
  const LiquidTag(this.label, {this.accent = false, this.color, super.key});

  final String label;
  final bool accent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = LiquidPalette.of(context);
    final fg = color ?? (accent ? p.accentText : p.textSecondary);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color != null
            ? color!.withValues(alpha: 0.16)
            : accent
            ? p.accent.withValues(alpha: 0.16)
            : p.text.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LiquidRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
        ),
      ),
    );
  }
}
