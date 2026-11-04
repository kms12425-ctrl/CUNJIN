/**
 * 寸进 · CUNJIN —— 设置面板
 *
 * 从 pages/Index.ets 的「Block Head Buttons / Settings」区域原样搬出。
 * 设置项、顺序、文案资源、尺寸、颜色、动画延迟阶梯（50/150/250/350/400/450/500/550/600/650/700/750/800）
 * 全部逐字保留，未做任何"顺手优化"。
 *
 * 通信约定（父页面仍是唯一事实来源与唯一持久化入口）：
 *   - 只读的配色/开关/数组        -> @Prop
 *   - 本组件会写入的状态          -> @Link（模糊半径、最小卡宽、两个配色编辑串、RESET 确认位、SegmentButton 选中项）
 *   - SegmentButtonOptions 是类实例 -> @Link（按引用传递，避免 @Prop 深拷贝破坏 Resource）
 *   - 需要页面方法/落盘的四个动作  -> 回调（onBlurCommit / onMinSizeCommit / onApply / onReset）
 * 本组件**不**直接读写 TaskRepository / Storage，也不保存任何设置副本。
 */

import { SegmentButton, SegmentButtonOptions } from '@ohos.arkui.advanced.SegmentButton';
import { JunHaoLeftTitle } from './atoms/LeftTitle';
import { JunHaoRightExplanation } from './atoms/RightExplanation';
import { ArchivedRow } from './ArchivedRow';
import { animateParam } from '../design/JunHaoUi';

@Component
export struct SettingsPanel {
  // 面板开合与配色：本组件只读，由页面控制
  @Prop STATUS_top_card_settings_is_open: boolean;
  @Prop DESIGN_font_color: string;
  @Prop DESIGN_block_background_color: string;
  @Prop DESIGN_color_scheme_light: string[];
  @Prop DESIGN_color_scheme_dark: string[];
  /** 已归档卡片：归档后会立刻从卡片流隐藏，这里集中查看与取消归档 */
  @Prop archived_ids: string[];
  @Prop archived_names: string[];

  // 本组件会写入的状态：必须双向绑定回页面
  @Link DESIGN_cards_blur_radius: number;
  @Link DESIGN_min_card_size: number;
  @Link SETTINGS_color_scheme_edit_light: string;
  @Link SETTINGS_color_scheme_edit_dark: string;
  @Link SETTINGS_reset_design_confirm: number;
  // SegmentButton 的选中项需要 `$` 双向绑定到底
  @Link UI_backdrop_choose: number[];
  // 类实例按引用传递（@Prop 会深拷贝，破坏其中的 Resource）
  @Link UI_backdrop_segment_button_options: SegmentButtonOptions;

  // 注意：「已归档」每行的"待确认删除"状态**不在这里**。
  // 早期把它放在本组件的 @State 里，结果点一行会让所有行一起变成"再点一次"；
  // 现在下沉到 ArchivedRow 各自的 @State，结构上互不影响。

  // 交由页面处理的动作（页面负责 persistSettings / 重算配色 / 重排 WaterFlow）
  onBlurCommit: () => void = () => {
  };
  onMinSizeCommit: () => void = () => {
  };
  onUnarchive: (id: string) => void = () => {
  };
  /** 删除一张已归档卡片；按钮自身负责"点两次才真正删除"的确认节奏 */
  onDeleteArchived: (id: string) => void = () => {
  };
  onApply: () => void = () => {
  };
  onReset: () => void = () => {
  };
  // 数据备份：文件选择与读写都在页面侧完成，组件只上报点击
  onExportData: () => void = () => {
  };
  onImportData: () => void = () => {
  };

  build() {
    Column({ space: 10 }) { // Settings
      Text($r("app.string.Settings_block_Settings"))
        .offset({ y: this.STATUS_top_card_settings_is_open ? 0 : 50 })
        .visibility(this.STATUS_top_card_settings_is_open ? Visibility.Visible : Visibility.Hidden)
        .animation(animateParam(this.STATUS_top_card_settings_is_open ? 50 : 0))
        .fontColor(this.DESIGN_font_color)
        .fontSize(25)
        .fontWeight(FontWeight.Bold)

      JunHaoLeftTitle({
        UI_text: $r("app.string.Settings_Content_Background"),
        STATUS_show: this.STATUS_top_card_settings_is_open,
        DESIGN_font_color: this.DESIGN_font_color,
        UI_delay: 100,
      })

      SegmentButton({
        options: this.UI_backdrop_segment_button_options, selectedIndexes: $UI_backdrop_choose
      })
        .offset({ y: this.STATUS_top_card_settings_is_open ? 0 : 50 })
        .visibility(this.STATUS_top_card_settings_is_open ? Visibility.Visible : Visibility.Hidden)
        .animation(animateParam(this.STATUS_top_card_settings_is_open ? 150 : 0))

      JunHaoLeftTitle({
        UI_text: $r("app.string.Settings_Content_Blur_Radius"),
        STATUS_show: this.STATUS_top_card_settings_is_open,
        DESIGN_font_color: this.DESIGN_font_color,
        UI_delay: 200,
      })

      Slider({
        style: SliderStyle.InSet,
        min: 1,
        max: 100,
        value: this.DESIGN_cards_blur_radius
      })
        .onChange((value: number, mode: SliderChangeMode) => {
          this.DESIGN_cards_blur_radius = value
          if (mode == SliderChangeMode.End || mode == SliderChangeMode.Click) {
            this.onBlurCommit()
          }
        })
        .offset({ y: this.STATUS_top_card_settings_is_open ? 0 : 50 })
        .visibility(this.STATUS_top_card_settings_is_open ? Visibility.Visible : Visibility.Hidden)
        .animation(animateParam(this.STATUS_top_card_settings_is_open ? 250 : 0))
        .blockColor(this.DESIGN_block_background_color)
        .selectedColor(this.DESIGN_font_color)

      JunHaoLeftTitle({
        UI_text: $r("app.string.Settings_Content_Min_Block_Size"),
        STATUS_show: this.STATUS_top_card_settings_is_open,
        DESIGN_font_color: this.DESIGN_font_color,
        UI_delay: 300,
      })

      Slider({
        style: SliderStyle.InSet,
        min: 300,
        max: 1000,
        value: this.DESIGN_min_card_size
      })
        .onChange((value: number, mode: SliderChangeMode) => {
          if (mode == SliderChangeMode.End || mode == SliderChangeMode.Click) {
            this.DESIGN_min_card_size = value
            this.onMinSizeCommit()
          }
        })
        .offset({ y: this.STATUS_top_card_settings_is_open ? 0 : 50 })
        .visibility(this.STATUS_top_card_settings_is_open ? Visibility.Visible : Visibility.Hidden)
        .animation(animateParam(this.STATUS_top_card_settings_is_open ? 350 : 0))
        .blockColor(this.DESIGN_block_background_color)
        .selectedColor(this.DESIGN_font_color)

      JunHaoRightExplanation({
        UI_text: $r("app.string.Settings_Content_Color_Scheme_Star"),
        STATUS_show: this.STATUS_top_card_settings_is_open,
        DESIGN_font_color: this.DESIGN_font_color,
        UI_max_lines: 3,
        UI_delay: 400,
      })

      JunHaoLeftTitle({
        UI_text: $r("app.string.Settings_Content_Color_Scheme_Light"),
        STATUS_show: this.STATUS_top_card_settings_is_open,
        DESIGN_font_color: this.DESIGN_font_color,
        UI_delay: 450,
      })

      TextArea({
        placeholder: this.DESIGN_color_scheme_light.toString(),
        text: this.DESIGN_color_scheme_light.toString()
      })
        .onChange((value) => {
          this.SETTINGS_color_scheme_edit_light = value
        })
        .height(81)
        .textOverflow(TextOverflow.Ellipsis)
        .offset({ y: this.STATUS_top_card_settings_is_open ? 0 : 50 })
        .visibility(this.STATUS_top_card_settings_is_open ? Visibility.Visible : Visibility.Hidden)
        .animation(animateParam(this.STATUS_top_card_settings_is_open ? 500 : 0))
        .fontColor(this.DESIGN_font_color)

      JunHaoLeftTitle({
        UI_text: $r("app.string.Settings_Content_Color_Scheme_Dark"),
        STATUS_show: this.STATUS_top_card_settings_is_open,
        DESIGN_font_color: this.DESIGN_font_color,
        UI_delay: 550,
      })

      TextArea({
        placeholder: this.DESIGN_color_scheme_dark.toString(), text: this.DESIGN_color_scheme_dark.toString()
      })
        .onChange((value) => {
          this.SETTINGS_color_scheme_edit_dark = value
        })
        .height(81)
        .textOverflow(TextOverflow.Ellipsis)
        .offset({ y: this.STATUS_top_card_settings_is_open ? 0 : 50 })
        .visibility(this.STATUS_top_card_settings_is_open ? Visibility.Visible : Visibility.Hidden)
        .animation(animateParam(this.STATUS_top_card_settings_is_open ? 600 : 0))
        .fontColor(this.DESIGN_font_color)

      JunHaoRightExplanation({
        UI_text: $r("app.string.Settings_Content_Color_Scheme_Description"),
        STATUS_show: this.STATUS_top_card_settings_is_open,
        DESIGN_font_color: this.DESIGN_font_color,
        UI_max_lines: 7,
        UI_delay: 650,
      })

      Button() {
        Text($r("app.string.General_OK"))
          .fontSize(15)
          .fontColor(this.DESIGN_block_background_color)
          .fontWeight(FontWeight.Bolder)
      }
      .width("100%")
      .padding(5)
      .backgroundColor(this.DESIGN_font_color)
      .onClick(() => {
        // 应用配色方案的完整动作留在页面（要重算配色、重排 WaterFlow 并落盘）
        this.onApply()
      })
      .offset({ y: this.STATUS_top_card_settings_is_open ? 0 : 50 })
      .visibility(this.STATUS_top_card_settings_is_open ? Visibility.Visible : Visibility.Hidden)
      .animation(animateParam(this.STATUS_top_card_settings_is_open ? 700 : 0))
      .clickEffect({ level: ClickEffectLevel.LIGHT })

      JunHaoRightExplanation({
        UI_text: $r("app.string.Settings_Content_Color_Scheme_Got_Messy"),
        STATUS_show: this.STATUS_top_card_settings_is_open,
        DESIGN_font_color: this.DESIGN_font_color,
        UI_max_lines: 1,
        UI_delay: 750,
      })

      Button() {
        Text(this.SETTINGS_reset_design_confirm == 0 ? $r("app.string.General_RESET") :
        $r('app.string.General_One_More_Confirm'))
          .fontSize(15)
          .fontColor(this.SETTINGS_reset_design_confirm == 0 ? this.DESIGN_block_background_color :
          this.DESIGN_font_color)
          .fontWeight(FontWeight.Bolder)
      }
      .width("100%")
      .padding(5)
      .backgroundColor(this.SETTINGS_reset_design_confirm == 0 ? this.DESIGN_font_color :
      this.DESIGN_block_background_color)
      .animation(animateParam(0))
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .offset({ y: this.STATUS_top_card_settings_is_open ? 0 : 50 })
      .visibility(this.STATUS_top_card_settings_is_open ? Visibility.Visible : Visibility.Hidden)
      .animation(animateParam(this.STATUS_top_card_settings_is_open ? 800 : 0))
      .onClick(() => { // RESET SCHEME
        // 两次确认的节奏与原来完全一致：第一次只翻确认位，第二次才真正重置
        if (this.SETTINGS_reset_design_confirm == 0) {
          this.SETTINGS_reset_design_confirm = 1
        } else if (this.SETTINGS_reset_design_confirm == 1) {
          this.SETTINGS_reset_design_confirm = 0
          this.onReset()
        }
      })

      // ── 数据备份（导出 / 导入）─────────────────────────────
      // 视觉与上面两颗按钮一致；延迟接在 800 之后，延续原有阶梯。
      Row({ space: 10 }) {
        Button() {
          Text('导出数据')
            .fontSize(15)
            .fontColor(this.DESIGN_block_background_color)
            .fontWeight(FontWeight.Bolder)
        }
        .layoutWeight(1)
        .padding(5)
        .backgroundColor(this.DESIGN_font_color)
        .clickEffect({ level: ClickEffectLevel.LIGHT })
        .onClick(() => {
          this.onExportData()
        })

        Button() {
          Text('导入数据')
            .fontSize(15)
            .fontColor(this.DESIGN_font_color)
            .fontWeight(FontWeight.Bolder)
        }
        .layoutWeight(1)
        .padding(5)
        .backgroundColor(this.DESIGN_block_background_color)
        .border({ width: 1, color: this.DESIGN_font_color })
        .clickEffect({ level: ClickEffectLevel.LIGHT })
        .onClick(() => {
          this.onImportData()
        })
      }
      .width("100%")
      .offset({ y: this.STATUS_top_card_settings_is_open ? 0 : 50 })
      .visibility(this.STATUS_top_card_settings_is_open ? Visibility.Visible : Visibility.Hidden)
      .animation(animateParam(this.STATUS_top_card_settings_is_open ? 850 : 0))

      // ── 已归档卡片 ─────────────────────────────────────
      // 归档后的卡片会立刻从卡片流隐藏，所以在这里集中查看与取消归档。
      if (this.archived_ids.length > 0) {
        Row() {
          Text('已归档')
            .fontSize(15)
            .fontColor(this.DESIGN_font_color)
            .fontWeight(FontWeight.Bolder)
            .layoutWeight(1)
          Text(this.archived_ids.length.toString() + ' 张')
            .fontSize(12)
            .fontColor(this.DESIGN_font_color)
            .opacity(0.6)
        }
        .width("100%")
        .padding(5)
        .margin({ top: 6 })

        ForEach(this.archived_ids, (id: string, index: number) => {
          // 每行是一个独立组件：删除的"两次确认"状态属于该行自己的 @State，
          // 所以点一行不会再让所有行一起变成"再点一次"。
          ArchivedRow({
            card_name: index < this.archived_names.length ? this.archived_names[index] : '',
            card_id: id,
            font_color: this.DESIGN_font_color,
            block_background_color: this.DESIGN_block_background_color,
            onUnarchive: (target: string) => {
              this.onUnarchive(target)
            },
            onDelete: (target: string) => {
              this.onDeleteArchived(target)
            }
          })
        }, (id: string, index: number) => id + '#' + index.toString())
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 20, right: 20 })
    .position({ y: 165 })
    .visibility(this.STATUS_top_card_settings_is_open ? Visibility.Visible : Visibility.None)
    .animation(animateParam(0))
  }
}
