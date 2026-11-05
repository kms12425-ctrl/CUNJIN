/**
 * 寸进 · CUNJIN —— 统计条（今日 / 近 7 天 / 连续 / 累计）
 *
 * 数据全部由 model/CardStats.ets 的纯函数在调用点算好后作为数字传入，
 * 组件本身不读页面状态、不碰存储，只负责渲染。
 *
 * 视觉沿用现有卡片规范：圆角 16、1px 边框 #4D7A7A7A、
 * backdrop 开启时半透明 + 模糊、关闭时用配色方案第 6 色作为卡片底色，
 * 数字用主题字色加粗、标签同色降透明度。未改动任何既有布局或动画。
 *
 * 文案暂用中文字面量（与工程内既有的占位符/提示一致），
 * 后续可统一迁到 string.json —— 本轮刻意不动资源文件，降低风险。
 */

@Component
export struct StatsPanel {
  @Prop today_hours: number;
  @Prop week_hours: number;
  @Prop streak_days: number;
  @Prop total_hours: number;
  @Prop active_days: number;

  @Prop font_color: string;
  @Prop block_background_color: string;
  @Prop use_backdrop: boolean;
  @Prop blur_radius: number;
  // 已解析好的卡片底色（开启图片背景时为透明）
  @Prop card_background: string;

  /** 小时数显示：0 显示 "0"，其余保留 1 位小数。 */
  private fmtHours(value: number): string {
    if (!Number.isFinite(value) || value == 0) {
      return '0';
    }
    return value.toFixed(1);
  }

  build() {
    FlowItem() {
      Column({ space: 10 }) {
        Row() {
          Column({ space: 2 }) {
            Text(this.fmtHours(this.today_hours))
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.font_color)
              .maxLines(1)
            Text('今日(小时)')
              .fontSize(12)
              .fontColor(this.font_color)
              .opacity(0.6)
              .maxLines(1)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)

          Column({ space: 2 }) {
            Text(this.fmtHours(this.week_hours))
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.font_color)
              .maxLines(1)
            Text('近7天(小时)')
              .fontSize(12)
              .fontColor(this.font_color)
              .opacity(0.6)
              .maxLines(1)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)

          Column({ space: 2 }) {
            Text(this.streak_days.toString())
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.font_color)
              .maxLines(1)
            Text('连续(天)')
              .fontSize(12)
              .fontColor(this.font_color)
              .opacity(0.6)
              .maxLines(1)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)

          Column({ space: 2 }) {
            Text(this.fmtHours(this.total_hours))
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.font_color)
              .maxLines(1)
            Text('累计(小时)')
              .fontSize(12)
              .fontColor(this.font_color)
              .opacity(0.6)
              .maxLines(1)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }
        .width("100%")
        .alignItems(VerticalAlign.Bottom)

        Text('累计打卡 ' + this.active_days.toString() + ' 天')
          .fontSize(12)
          .fontColor(this.font_color)
          .opacity(0.5)
          .maxLines(1)
          .width("100%")
      }
      .width("100%")
      .height("100%")
      .alignItems(HorizontalAlign.Start)
      .padding(16)
    }
    .height(120)
    .width("100%")
    .borderRadius(16)
    .border({ width: 1, color: "#4D7A7A7A" })
    .backgroundEffect({
      radius: this.use_backdrop ? this.blur_radius : 0,
      color: this.block_background_color
    })
    .backgroundColor(this.card_background)
  }
}
