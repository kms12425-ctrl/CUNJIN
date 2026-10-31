/**
 * 寸进 · CUNJIN —— 多行文本输入原子组件（编辑卡片名/描述）
 *
 * 从 pages/Index.ets 原样搬出，未改动布局、尺寸、颜色、动效参数或文案。
 */

@Component
export struct JunHaoTextArea {
  @Prop STATUS_show: boolean
  @Prop DESIGN_font_color: string = "#FFFFFF"
  @Link UI_text: string
  @State UI_delay: number = 0
  @State UI_placeholder: string = "placeholder!"
  @State UI_area_height: number = 39

  build() {
    TextArea({ placeholder: this.UI_placeholder, text: this.UI_text })
      .fontColor(this.DESIGN_font_color)
      .onChange((value) => {
        this.UI_text = value
      })
      .height(this.UI_area_height)
      .textOverflow(TextOverflow.Ellipsis)
      .offset({ y: this.STATUS_show ? 0 : 50 })
      .visibility(this.STATUS_show ? Visibility.Visible : Visibility.Hidden)
      .animation(this.animateParam(this.STATUS_show ? this.UI_delay : 0))
  }

  animateParam(delay: number) {
    let ap: AnimateParam = { delay: delay, duration: 300, curve: Curve.ExtremeDeceleration }
    return ap
  }
}
