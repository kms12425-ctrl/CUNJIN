/**
 * 寸进 · CUNJIN —— 卡片详情：基础信息块（名称 / 已完成 ÷ 目标 / 描述）
 *
 * 从 pages/Index.ets 的「BASIC INFO」FlowItem 原样搬出。
 * 尺寸、字号、颜色、动画延迟（150 / 200 / 250）与三段入场逻辑逐字保留。
 *
 * 注意（保留原有的不一致，不要"修"）：
 * 标题与描述用的是 STATUS_card_index_of_last_expanded，
 * 而「目标值」用的是 STATUS_card_expanding —— 这是原代码的真实行为。
 * 这里通过不同入参把这两个下标各自的取值结果分别传进来，语义不变。
 */

import { animateParam } from '../design/JunHaoUi';

@Component
export struct CardInfoBlock {
  @Prop card_name: string;
  @Prop card_desc: string;
  @Prop card_target: number;
  // 已完成小时数的显示文本（保留原表达式：undefined -> ""，否则 toFixed(2)）
  @Prop done_text: string;
  @Prop font_color: string;
  // == DETAILS_is_not_viewing_detail()
  @Prop detail_hidden: boolean;

  build() {
    FlowItem() {
      Column() {
        Text(this.card_name)
          .fontSize(30)
          .fontColor(this.font_color)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 6 })
          .maxLines(1)
          .textAlign(TextAlign.Start)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .offset({ y: this.detail_hidden ? 100 : 0 })
          .visibility(this.detail_hidden ? Visibility.Hidden : Visibility.Visible)
          .animation(animateParam(this.detail_hidden ? 0 : 150))
          .width("100%") // TITLE

        Row() {
          Text(this.done_text)
            .fontSize(50)
            .fontColor(this.font_color)
            .fontWeight(FontWeight.Bold)
          Text("／" + (this.card_target == 1001 ? " ∞ " : String(this.card_target)))
            .fontSize(16)
            .fontColor(this.font_color)
            .fontWeight(FontWeight.Medium)
          Text($r('app.string.Add_Value_Unit_Hour'))
            .fontSize(16)
            .fontColor(this.font_color)
            .fontWeight(FontWeight.Medium)
        }
        .offset({ y: (this.detail_hidden) ? 100 : 0 })
        .visibility((this.detail_hidden) ? Visibility.Hidden : Visibility.Visible)
        .animation(animateParam(this.detail_hidden ? 0 : 200))
        .alignItems(VerticalAlign.Bottom)
        .margin({ bottom: 14 })
        .width("100%")

        // BIG DIGITS

        Text("“" + this.card_desc + "”")
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(this.font_color)
          .offset({ y: (this.detail_hidden) ? 100 : 0 })
          .visibility((this.detail_hidden) ? Visibility.Hidden : Visibility.Visible)
          .animation(animateParam(250))
          .width("100%")
      }.width("100%").height("100%")
    }.width("100%").height(190)
  }
}
