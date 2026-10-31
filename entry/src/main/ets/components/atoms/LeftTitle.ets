/**
 * 寸进 · CUNJIN —— 设置项左侧标题原子组件
 *
 * 从 pages/Index.ets 原样搬出，未改动布局、尺寸、颜色、动效参数或文案。
 */

@Component
export struct JunHaoLeftTitle {
  @Prop DESIGN_font_color: string = "#FFFFFF"
  @Prop STATUS_show: boolean = false
  @Prop UI_delay: number = 0
  @State UI_text: string | Resource = "喵"
  @State UI_max_lines: number = 1

  build() {
    Text(this.UI_text)
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .offset({ y: this.STATUS_show ? 0 : 50 })
      .visibility(this.STATUS_show ? Visibility.Visible : Visibility.Hidden)
      .maxLines(this.UI_max_lines)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .animation({ delay: this.UI_delay, duration: 300, curve: Curve.ExtremeDeceleration })
      .fontColor(this.DESIGN_font_color)
      .animation({ duration: 300, curve: Curve.ExtremeDeceleration })
  }
}
