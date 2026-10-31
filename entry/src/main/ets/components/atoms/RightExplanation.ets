/**
 * 寸进 · CUNJIN —— 设置项右侧说明文字原子组件
 *
 * 从 pages/Index.ets 原样搬出，未改动布局、尺寸、颜色、动效参数或文案。
 */

@Component
export struct JunHaoRightExplanation {
  @Prop STATUS_show: boolean = false
  @Prop DESIGN_font_color: string = "#FFFFFF"
  @State UI_delay: number = 0
  @Prop UI_text: string | Resource = "喵"
  @State UI_max_lines: number = 999

  build() {
    Text(this.UI_text)
      .fontSize(15)
      .fontWeight(FontWeight.Regular)
      .textAlign(TextAlign.End)
      .width("100%")
      .maxLines(this.UI_max_lines)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .offset({ y: this.STATUS_show ? 0 : 50 })
      .visibility(this.STATUS_show ? Visibility.Visible : Visibility.Hidden)
      .animation({ delay: this.UI_delay, duration: 300, curve: Curve.ExtremeDeceleration })
      .fontColor(this.DESIGN_font_color)
      .animation({ duration: 300, curve: Curve.ExtremeDeceleration })
  }
}
