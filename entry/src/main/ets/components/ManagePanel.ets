/**
 * 寸进 · CUNJIN —— 管理面板（置顶 / 删除卡片）
 *
 * 从 pages/Index.ets 的「MANAGING」FlowItem 原样搬出（原 86 行）。
 * 标题、两个按钮的文案、配色、圆角、内边距、高度、动画延迟（0 / 700）
 * 以及「两次确认删除」的文案与配色三元表达式全部逐字保留。
 *
 * ── 为什么这里只有回调、没有 @Link ──────────────────────────
 * 两个按钮的 onClick 体都**留在父页面**，因为它们是纯数据操作：
 *   · 置顶：VIEW_move_card_to_index() + 两个下标复位 + scroller_main.scrollToIndex(2)
 *   · 删除：连续 9 个数组 splice + PRIVATE cardIds 摘除 + scroller_card_expand 复位
 *           + 两个下标改写 + CARD_storeCards()
 * 其中 cardIds 是页面私有字段，两个 Scroller 也是页面私有成员，
 * 无法作为组件属性传递，硬搬会破坏封装或改变语义。
 * 因此组件只负责"长什么样 + 点哪了"，状态与落盘全部由父页面执行，
 * 顺序与拆分前完全一致（含"删除前先判断是否正在计时"的提前 return）。
 *
 * 组件不读写 TaskRepository / Storage，不持有任何卡片数据副本。
 */

import { animateParam } from '../design/JunHaoUi';

@Component
export struct ManagePanel {
  // 只读投影：用于按钮文案与配色判断
  @Prop card_name: string;
  @Prop working_card_name: string;
  @Prop delete_confirm: boolean;
  @Prop font_color: string;
  @Prop block_background_color: string;
  @Prop detail_hidden: boolean;
  /** 归档的二次确认位：与删除一样，点第一次只翻这个标记 */
  @Prop archive_confirm: boolean;

  // 按钮动作，方法体留在父页面
  onMoveToTop: () => void = () => {
  };
  onArchive: () => void = () => {
  };
  onDeleteCard: () => void = () => {
  };

  build() {
    FlowItem() {
      Column({ space: 10 }) {

        Text($r("app.string.Card_Progress_Title_Manage"))
          .fontSize(22)
          .maxLines(1)
          .fontColor(this.font_color)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 15 })

        Button() {
          Text($r("app.string.Card_Progress_Manage_Move_To_Top"))
            .fontSize(15)
            .fontColor(this.block_background_color)
            .fontWeight(FontWeight.Bolder)
            .animation(animateParam(0))
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT })
        .width("100%")
        .padding(5)
        .backgroundColor(this.font_color)
        .onClick(() => {
          this.onMoveToTop()
        })

        // MOVE TO TOP BUTTON

        // 归档（与删除一样是"两次点击"：第一次只翻确认位）
        Button() {
          Text(this.archive_confirm == false ? '归档' :
            $r("app.string.General_One_More_Confirm"))
            .fontSize(15)
            .fontColor(this.font_color)
            .fontWeight(FontWeight.Bolder)
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT })
        .width("100%")
        .padding(5)
        .backgroundColor(this.block_background_color)
        .border({ width: 1, color: this.font_color })
        .onClick(() => {
          // 预览器增量编译偶尔会保留旧的组件模块（回调属性没注入），
          // 这里做一次存在性判断，避免直接抛 "undefined is not callable"。
          if (typeof this.onArchive === 'function') {
            this.onArchive()
          }
        })

        Button() {
          Text(this.card_name == this.working_card_name ?
          $r('app.string.Card_Progress_Manage_Delete_Cannot_Ongoing') :
            this.delete_confirm == false ? $r("app.string.Card_Progress_Manage_Delete") :
            $r("app.string.General_One_More_Confirm"))
            .fontSize(15)
            .fontColor(this.delete_confirm == false ? this.block_background_color :
            this.font_color)
            .fontWeight(FontWeight.Bolder)
        }
        .width("100%")
        .padding(5)
        .backgroundColor(this.delete_confirm == false ? this.font_color :
        this.block_background_color)
        .animation(animateParam(0))
        .clickEffect({ level: ClickEffectLevel.LIGHT })
        .onClick(() => {
          this.onDeleteCard()
        })

        // DELETE CARD BUTTON

      }.alignItems(HorizontalAlign.Start).height("100%").width("100%")
    }.width("100%").height(400)
    .offset({ y: (this.detail_hidden) ? 100 : 0 })
    .visibility((this.detail_hidden) ? Visibility.Hidden : Visibility.Visible)
    .animation(animateParam(this.detail_hidden ? 0 : 700))
  }
}
