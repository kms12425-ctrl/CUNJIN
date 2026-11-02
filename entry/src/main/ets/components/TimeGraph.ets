/**
 * 寸进 · CUNJIN —— 卡片详情：剩余时间环
 *
 * 从 pages/Index.ets 的「TIME LEFT GRAPH」FlowItem 原样搬出。
 * 保留 367（无限期）时的特例取值：0.5 * time_limit + 1，此时 max 仍为 time_limit。
 * 颜色直接取主题色（不是渐变）、indicator(null)、高度 250/200 全部保持不变。
 */

import { animateParam } from '../design/JunHaoUi';

@Component
export struct TimeGraph {
  // 时段标语资源名（子组件内仍用 $r(...) 解析，与原写法一致）
  @Prop slogan_key: string;
  @Prop time_limit: number;
  // == UI_card_expanded_remaining_days
  @Prop remaining_days: number;
  // == CARD_get_time_left_percentage()
  @Prop time_left_percentage: string;
  @Prop font_color: string;
  @Prop detail_hidden: boolean;
  @Prop wide_screen: boolean;

  build() {
    FlowItem() {
      Column() {
        Text($r(this.slogan_key))
          .offset({ y: (this.detail_hidden) ? 100 : 0 })
          .visibility((this.detail_hidden) ? Visibility.Hidden : Visibility.Visible)
          .animation(animateParam(this.detail_hidden ? 0 : 400))
          .fontSize(22)
          .maxLines(1)
          .fontColor(this.font_color)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 15 })

        Gauge({
          value: this.time_limit == 367 ? 0.5 * this.time_limit + 1 : this.remaining_days,
          min: 0,
          max: this.time_limit
        }) {
          Column() {
            Text(this.time_left_percentage)
              .fontWeight(FontWeight.Medium)
              .fontSize(20)
              .fontColor(this.font_color)
              .textAlign(TextAlign.Center)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)
              .margin({ top: '34%' })
            Text($r('app.string.Card_Progress_Remaining_Time'))
              .fontWeight(FontWeight.Medium)
              .fontSize(16)
              .fontColor(this.font_color)
              .textAlign(TextAlign.Center)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)
          }.height("100%")
        }
        .offset({ y: (this.detail_hidden) ? 100 : 0 })
        .visibility((this.detail_hidden) ? Visibility.Hidden : Visibility.Visible)
        .animation(animateParam(this.detail_hidden ? 0 : 450))
        .indicator(null)
        .startAngle(225)
        .endAngle(135)
        .colors(this.font_color)
        .strokeWidth(18)
        .trackShadow({ radius: 7, offsetX: -7, offsetY: 7 })
        .height(180)
      }.alignItems(HorizontalAlign.Center).width("100%")
    }.width("100%").height(this.wide_screen ? 250 : 200)
  }
}
