/**
 * 寸进 · CUNJIN —— 编辑卡片面板（名称 / 描述 / 卡片长度）
 *
 * 从 pages/Index.ets 的「SETTINGS I」FlowItem 原样搬出（原 113 行）。
 * 输入项、顺序、默认占位符、校验阈值（<270 / <330）、字号、尺寸、高度、动画延迟（600/0/400/650）
 * 全部逐字保留。UI 未重新设计。
 *
 * ── 关于「数组元素原地修改」的处理（本轮关键决定）──────────────
 * 原实现在确认按钮里做三处数组元素赋值：
 *     DATA_cards_name[last] = EDIT_name
 *     DATA_cards_desc[last] = EDIT_description（空则回填 "喵 meow"）
 *     DATA_cards_length[last] = EDIT_length
 * 这三处**没有**搬进组件，而是留在父页面的 onSave() 回调里执行。理由：
 *   1. ArkUI V1 里 @Link 传数组确实能双向写元素，但元素赋值能否被父页面稳定观察、
 *      以及随后 CARD_storeCards() 是否能读到最新值，属于运行期行为，无设备时无法证明；
 *   2. 确认时还有一步"同步计时状态里的卡片名 + persistWorkState()"，
 *      它与三处赋值有严格先后顺序，拆到两个组件里更容易走错；
 *   3. 因此组件只负责"本地编辑态 + 回调"，父页面保持唯一的事实源与唯一的提交点，
 *      写入顺序与拆分前完全一致。
 * 结果是：没有任何数组跨组件边界，从根本上消除了错位与漏更新的可能。
 *
 * 组件不读写 TaskRepository / Storage，不保存卡片数据副本。
 */

import { JunHaoLeftTitle } from './atoms/LeftTitle';
import { JunHaoRightExplanation } from './atoms/RightExplanation';
import { animateParam } from '../design/JunHaoUi';

@Component
export struct EditCard {
  // ── 只读：由父页面投影进来的显示值 ─────────────────────────
  // 三个输入控件的初始值（原来直接读 DATA_cards_*[last]）
  @Prop card_name: string;
  @Prop card_desc: string;
  @Prop card_length: number;
  // 子标题/说明的显示开关：原来写作 STATUS_card_expanding != -1
  @Prop STATUS_card_expanding: number;
  @Prop font_color: string;
  @Prop block_background_color: string;
  // == DETAILS_is_not_viewing_detail()
  @Prop detail_hidden: boolean;

  // ── 双向：编辑中的临时值 ───────────────────────────────────
  // 这四个本来就是页面级 @State，同时被 CardBlock 在点击卡片时播种、
  // 被下面三个控件改写，所以必须用 @Link 而不是 @Prop。
  @Link EDIT_name: string;
  @Link EDIT_description: string;
  @Link EDIT_length: number;
  @Link EDIT_length_description: string;

  // ── 输出：提交动作留给父页面 ───────────────────────────────
  onSave: () => void = () => {
  };

  build() {
    FlowItem() {
      Column({ space: 10 }) {
        Text($r("app.string.Settings_block_Settings"))
          .fontSize(22)
          .maxLines(1)
          .fontColor(this.font_color)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 15 })

        JunHaoLeftTitle({
          UI_text: $r("app.string.Add_Name_Title"),
          STATUS_show: this.STATUS_card_expanding != -1,
          DESIGN_font_color: this.font_color,
          UI_delay: 600,
        })

        TextArea({
          placeholder: "=￣ω￣=", text: this.card_name
        }).fontColor(this.font_color).onChange((value) => {
          this.EDIT_name = value
        }).height(39).textOverflow(TextOverflow.Ellipsis)

        // CARD NAME

        JunHaoLeftTitle({
          UI_text: $r("app.string.Add_Description"),
          STATUS_show: this.STATUS_card_expanding != -1,
          DESIGN_font_color: this.font_color,
          UI_delay: 0,
        })

        TextArea({
          placeholder: "(〃￣︶￣)人(￣︶￣〃)", text: this.card_desc
        }).fontColor(this.font_color).onChange((value) => {
          this.EDIT_description = value
        }).height(81).textOverflow(TextOverflow.Ellipsis)

        // CARD DESCRIPTION

        JunHaoLeftTitle({
          UI_text: $r("app.string.Add_Length"),
          STATUS_show: this.STATUS_card_expanding != -1,
          DESIGN_font_color: this.font_color,
          UI_delay: 0,
        })

        Slider({
          style: SliderStyle.InSet,
          min: 200,
          max: 400,
          value: this.card_length
        })
          .blockColor(this.block_background_color)
          .selectedColor(this.font_color)
          .onChange((value: number, _mode: SliderChangeMode) => {
            this.EDIT_length = value
            if (value < 270) {
              this.EDIT_length_description = "app.string.Add_Length_Notice_Short"
            } else if (value < 330) {
              this.EDIT_length_description = "app.string.Add_Length_Notice_Medium"
            } else {
              this.EDIT_length_description = "app.string.Add_Length_Notice_Long"
            }
          })

        JunHaoRightExplanation({
          UI_text: $r(this.EDIT_length_description),
          STATUS_show: this.STATUS_card_expanding != -1,
          DESIGN_font_color: this.font_color,
          UI_max_lines: 1,
          UI_delay: 400,
        })

        // CARD LENGTH

        Button() {
          Text($r("app.string.General_OK"))
            .fontSize(15)
            .fontColor(this.block_background_color)
            .fontWeight(FontWeight.Bolder)
            .animation(animateParam(0))
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT })
        .width("100%")
        .padding(5)
        .backgroundColor(this.font_color)
        .onClick(() => { // Save Card
          // 提交顺序（同步计时状态 → 写名称/描述/长度 → 落盘）留在父页面，逐行未变
          this.onSave()
        })

        // CONFIRM BUTTON
      }.alignItems(HorizontalAlign.Start).height("100%")
    }.width("100%").height(400)
    .offset({ y: (this.detail_hidden) ? 100 : 0 })
    .visibility((this.detail_hidden) ? Visibility.Hidden : Visibility.Visible)
    .animation(animateParam(this.detail_hidden ? 0 : 650))
  }
}
