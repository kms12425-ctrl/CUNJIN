/**
 * 寸进 · CUNJIN —— 大标题区（"寸进 / 日有寸进"）
 *
 * 从 pages/Index.ets 原样搬出。注意两条动画链的顺序是有意义的：
 *   .animation(animateParam(200))  ->  .onAreaChange(...)  ->  .animation(animateParam(0))
 * 前者负责入场，后者把后续属性变更改为无动画；顺序不能调换。
 */

import { animateParam } from '../design/JunHaoUi';

@Component
export struct HeroHeader {
  // 四个入场动画状态由本组件内的 onAreaChange 写入，因此必须是 @Link
  @Link UI_Title_opacity: number;
  @Link UI_Title_y_offset: number;
  @Link UI_subTitle_y_offset: number;
  @Link UI_subTitle_opacity: number;
  @Prop UI_Title_font_zoom: number;
  @Prop UI_Title_top_margin: number;
  @Prop DESIGN_font_color: string;

  build() {
    Row() {
      Text($r("app.string.Entry_Title"))
        .fontSize(45 * this.UI_Title_font_zoom)
        .fontWeight(FontWeight.Bolder)
        .position({ y: this.UI_Title_y_offset })
        .opacity(this.UI_Title_opacity)
        .animation(animateParam(200))
        .onAreaChange(() => {
          this.UI_Title_opacity = 100
          this.UI_Title_y_offset = 0
        })
        .fontColor(this.DESIGN_font_color)
        .animation(animateParam(0))

      Text($r("app.string.Entry_Subtitle"))
        .fontSize(20 * this.UI_Title_font_zoom)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 65 * this.UI_Title_font_zoom })
        .position({ y: this.UI_subTitle_y_offset })
        .opacity(this.UI_subTitle_opacity)
        .animation(animateParam(300))
        .onAreaChange(() => {
          this.UI_subTitle_y_offset = 0
          this.UI_subTitle_opacity = 100
        })
        .fontColor(this.DESIGN_font_color)
        .animation(animateParam(0))
    }
    .position({ y: this.UI_Title_top_margin + 20 })
    .width("100%")
    .animation(animateParam(0))
    .padding({ left: 20 })
  }
}
