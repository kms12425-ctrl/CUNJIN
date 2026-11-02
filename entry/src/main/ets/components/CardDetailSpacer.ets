/**
 * 寸进 · CUNJIN —— 卡片详情弹层顶部的占位/复位条
 *
 * 从 pages/Index.ets 弹层 Column 的第一个子节点原样搬出（原 13 行）。
 * 该 Row 本身不显示任何内容，作用是：
 *   · 撑出弹层顶部留白（关闭时 0.25 屏高，展开时 1 屏高）；
 *   · 在高度变化（= 展开/收起动作发生）时，把"删除二次确认"复位，
 *     并让数据看板跳回今天。
 *
 * 高度表达式、动画字面量（delay 50 / duration 350 / ExtremeDeceleration）逐字保留。
 * 这里刻意**没有**使用 animateParam()，因为原代码就不是 300ms。
 *
 * 复位逻辑本身（写父页面两个状态 + 调 CARD_get_today_block_index()）留在父页面的
 * onReset 回调里，组件不持有任何卡片数据。
 *
 * 注意：本组件是 Row 作为根节点，`onAreaChange` 挂在根上；
 * 同一模式已在本工程的 StartupCover.ets 中使用，属既有可行写法。
 */

@Component
export struct CardDetailSpacer {
  // == DETAILS_is_not_viewing_detail()
  @Prop detail_hidden: boolean;
  // == ENVIRONMENT_screen_height
  @Prop screen_height: number;

  // 展开/收起时由父页面执行的状态复位
  onReset: () => void = () => {
  };

  build() {
    Row() {
    }
    .height(this.detail_hidden ? this.screen_height * 1 :
      this.screen_height * 0.25)
    .animation({ delay: 50, duration: 350, curve: Curve.ExtremeDeceleration })
    .onAreaChange(() => {
      this.onReset()

      // RESET CARDS WHEN EXPANDING

    })
  }
}
