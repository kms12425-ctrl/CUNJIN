/**
 * 寸进 · CUNJIN —— 卡片详情：已完成进度环
 *
 * 从 pages/Index.ets 的「DONE GRAPH」FlowItem 原样搬出。
 * 渐变三段颜色、startAngle/endAngle、strokeWidth、trackShadow、高度全部逐字保留；
 * 目标值为 1001（无限）时 max 取 999 的特例也保留。
 */

import { animateParam } from '../design/JunHaoUi';

@Component
export struct DoneGraph {
  @Prop done_value: number;
  // == CARD_get_done_percentage()
  @Prop done_percentage: string;
  @Prop target: number;
  @Prop font_color: string;
  @Prop detail_hidden: boolean;
  @Prop wide_screen: boolean;

  build() {
    FlowItem() {
      Column() {
        Gauge({
          value: this.done_value,
          min: 0,
          max: this.target == 1001 ? 999 : this.target
        }) {
          Column() {
            Text(this.done_percentage)
              .fontWeight(FontWeight.Medium)
              .fontSize(20)
              .fontColor(this.font_color)
              .textAlign(TextAlign.Center)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)
              .margin({ top: '34%' })
            Text($r('app.string.Card_Progress_Done'))
              .fontWeight(FontWeight.Medium)
              .fontSize(16)
              .fontColor(this.font_color)
              .textAlign(TextAlign.Center)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)
          }.height("100%")
        }
        .startAngle(225)
        .endAngle(135)
        .colors(new LinearGradient([{ color: "#D0e84026", offset: 0 }, { color: "#D0f7ce00", offset: 0.6 },
          { color: "#D064bb5c", offset: 1 }]))
        .strokeWidth(18)
        .trackShadow({ radius: 7, offsetX: -7, offsetY: 7 })
        .height(180)
      }
      .offset({ y: (this.detail_hidden) ? 100 : 10 })
      .visibility(this.detail_hidden ? Visibility.Hidden : Visibility.Visible)
      .alignItems(this.wide_screen ? HorizontalAlign.End : HorizontalAlign.Center)
      .animation(animateParam(this.detail_hidden ? 0 : 350))
      .width("100%")
      .height("100%")
    }.width("100%").height(this.wide_screen ? 190 : 200)
  }
}
