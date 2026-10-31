/**
 * 寸进 · CUNJIN —— 带图标/文字切换的符号按钮原子组件
 *
 * 从 pages/Index.ets 原样搬出，未改动布局、尺寸、颜色、动效参数或文案。
 */

@Component
export struct JunHaoSymbolButton {
  @Prop STATUS_switch_to_arrow: boolean;
  @Prop STATUS_trigger: boolean;
  @Prop DESIGN_font_color: string;
  @State UI_image: Resource = $r('sys.symbol.plus')
  @State UI_text: Resource | string = $r("app.string.Settings_block_Settings")
  @State UI_image_size: number = 30

  build() {
    Column() {
      SymbolGlyph(this.STATUS_switch_to_arrow ? $r("sys.symbol.chevron_down") : this.UI_image)
        .fontSize(this.UI_image_size)
        .fontColor([this.DESIGN_font_color as ResourceColor, this.DESIGN_font_color as ResourceColor,
          this.DESIGN_font_color as ResourceColor])// .effectStrategy(1)
        .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.STATUS_trigger))

      Text(this.UI_text).margin({ top: 10 }).fontColor(this.DESIGN_font_color)
    }.padding(15).backgroundColor(Color.Transparent).borderRadius(8)
  }
}
