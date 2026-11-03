/**
 * 寸进 · CUNJIN —— 「这一天的备注」
 *
 * 数据看板下面的一格输入：给"当前选中的那一天"写一句备注。
 * 备注存在 TaskCardData.notes 里，与 punchCard 等长、下标含义相同，
 * 所以每天各有一条，切换日期就切换内容。
 *
 * 组件不持有任何卡片数据：文本由父页面按 (卡片下标, 日期下标) 传入，
 * 输入通过 onEdit 回传，落盘仍由父页面的 CARD_storeCards() 完成。
 */

@Component
export struct DayNotePanel {
  /** 当前选中那天的备注文本 */
  @Prop note_text: string;
  /** 当前选中那天的日期文本（如 "2023／11／15"） */
  @Prop date_text: string;
  @Prop detail_hidden: boolean;

  @Prop font_color: string;
  @Prop block_background_color: string;
  @Prop use_backdrop: boolean;
  @Prop blur_radius: number;
  @Prop card_background: string;

  onEdit: (text: string) => void = () => {
  };

  build() {
    FlowItem() {
      Column({ space: 6 }) {
        Row() {
          Text(this.date_text + ' 的备注')
            .fontSize(12)
            .fontColor(this.font_color)
            .opacity(0.7)
            .maxLines(1)
            .layoutWeight(1)
        }
        .width("100%")

        TextArea({ placeholder: '这一天做了什么、卡在哪里……', text: this.note_text })
          .fontSize(14)
          .fontColor(this.font_color)
          .placeholderColor(this.font_color)
          .backgroundColor("#00000000")
          .borderRadius(8)
          .border({ width: 1, color: "#4D7A7A7A" })
          .padding(8)
          .height(76)
          .width("100%")
          .onChange((value: string) => {
            this.onEdit(value)
          })
      }
      .width("100%")
      .alignItems(HorizontalAlign.Start)
      .padding(16)
    }
    .width("100%")
    .borderRadius(16)
    .border({ width: 1, color: "#4D7A7A7A" })
    .backgroundEffect({
      radius: this.use_backdrop ? this.blur_radius : 0,
      color: this.block_background_color
    })
    .backgroundColor(this.card_background)
    .offset({ y: this.detail_hidden ? 100 : 0 })
    .visibility(this.detail_hidden ? Visibility.Hidden : Visibility.Visible)
  }
}
