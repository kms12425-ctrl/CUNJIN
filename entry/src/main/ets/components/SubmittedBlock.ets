/**
 * 寸进 · CUNJIN —— 卡片详情：某一天的已提交工时
 *
 * 从 pages/Index.ets 的「DATA BOARD」FlowItem 原样搬出。
 * 大号数字仍保留 4 位小数显示（toFixed(4)），日期文本仍取 CARD_get_date_of_chosen()[0]。
 */

import { animateParam } from '../design/JunHaoUi';

@Component
export struct SubmittedBlock {
  // 已提交工时文本（保留原表达式：下标为 -1 时显示 "0"，否则 toFixed(4)）
  @Prop submitted_text: string;
  // == CARD_get_date_of_chosen()[0]
  @Prop date_text: string;
  @Prop font_color: string;
  @Prop detail_hidden: boolean;
  @Prop wide_screen: boolean;

  build() {
    FlowItem() {
      Column({ space: 5 }) {
        Text($r("app.string.Data_Board_Submitted"))
          .fontSize(16)
          .fontColor(this.font_color)
        Text(this.submitted_text)
          .fontSize(40)
          .fontColor(this.font_color)
          .fontWeight(FontWeight.Bold)
        Text($r("app.string.Data_Board_Submitted_Hours_Of_Work"))
          .fontSize(16)
          .fontColor(this.font_color)
        Text(this.date_text)
          .fontSize(24)
          .fontColor(this.font_color)
          .fontWeight(FontWeight.Bold)
          .opacity(0.5)
          .margin({ top: 20 })
      }

    }
    .offset({ y: (this.detail_hidden) ? 100 : 0 })
    .visibility((this.detail_hidden) ? Visibility.Hidden : Visibility.Visible)
    .animation(animateParam(this.detail_hidden ? 0 : 600))
    .width("100%")
    .height(this.wide_screen ? 270 : 200)
  }
}
