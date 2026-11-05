/**
 * 寸进 · CUNJIN —— 「已归档」列表里的一行
 *
 * 为什么单独做成组件：删除的"两次确认"必须是**每一行各自独立**的状态。
 * 如果把它放在设置面板的 @State 里（早期写法），一次点击会让所有行同时变成
 * "再点一次" —— 因为 ForEach 里每一行读的都是同一个组件级状态，按 id 比较在
 * 复用/重建时并不可靠。把确认态下沉成每行实例自己的 @State 之后，
 * 点哪一行就只影响哪一行，结构上不可能串。
 *
 * 组件只上报点击，删除/取消归档的实际数据操作仍留在父页面。
 */

@Component
export struct ArchivedRow {
  @Prop card_name: string;
  @Prop card_id: string;
  @Prop font_color: string;
  @Prop block_background_color: string;

  onUnarchive: (id: string) => void = () => {
  };
  onDelete: (id: string) => void = () => {
  };

  /** 本行是否处于"待确认删除"。每个实例独立，互不影响。 */
  @State confirm_delete: boolean = false;

  build() {
    // 名字一行、按钮一行：避免三个元素挤在一行时第三个被裁到可视区域外
    Column({ space: 4 }) {
      Text(this.card_name)
        .fontSize(13)
        .fontColor(this.font_color)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width("100%")

      Row({ space: 8 }) {
        // 删除在「取消归档」左边；两步确认：第一次只翻本行的确认态。
        Button() {
          Text(this.confirm_delete ? '再点一次' : '删除')
            .fontSize(11)
            .fontColor(this.confirm_delete ? this.block_background_color : this.font_color)
            .fontWeight(FontWeight.Bolder)
        }
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor(this.confirm_delete ? this.font_color : "#00000000")
        .border({ width: 1, color: this.font_color })
        .clickEffect({ level: ClickEffectLevel.LIGHT })
        .onClick(() => {
          if (this.confirm_delete) {
            this.confirm_delete = false
            this.onDelete(this.card_id)
          } else {
            this.confirm_delete = true
          }
        })

        Button() {
          Text('取消归档')
            .fontSize(11)
            .fontColor(this.block_background_color)
            .fontWeight(FontWeight.Bolder)
        }
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor(this.font_color)
        .clickEffect({ level: ClickEffectLevel.LIGHT })
        .onClick(() => {
          // 取消归档前先清掉本行的待确认态，避免"取消归档后仍停在再点一次"
          this.confirm_delete = false
          this.onUnarchive(this.card_id)
        })
      }
      .width("100%")
    }
    .width("100%")
    .padding({ left: 5, right: 5, top: 3, bottom: 3 })
  }
}
