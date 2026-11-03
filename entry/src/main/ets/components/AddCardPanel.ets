/**
 * 寸进 · CUNJIN —— 新建卡片面板
 *
 * 从 pages/Index.ets 的「Block Head Buttons / Add Content」区域原样搬出。
 * 设置项顺序、文案资源、尺寸、取值范围（200~400 / 1~367 / 1~1001）、
 * 动画延迟阶梯（50/100/150/200/250/300/350/400/450/500/550/600/650/700/750）
 * 与所有边界判断（<270 / <330 / ==367 / >=367 / ==1001 / >=1001）全部逐字保留。
 *
 * 通信约定：
 *   - 只读：面板开合位、配色、两个输入框的初值  -> @Prop
 *   - 本面板会写：长度、长度说明、时间上限、时间单位说明、目标值、目标值说明 -> @Link
 *   - 真正建卡（含落盘）仍由页面执行 -> onAdd 回调
 * 本组件不读写 Storage / TaskRepository，不保存任何副本。
 */

import { JunHaoLeftTitle } from './atoms/LeftTitle';
import { JunHaoRightExplanation } from './atoms/RightExplanation';
import { JunHaoTextArea } from './atoms/TextArea';
import { animateParam } from '../design/JunHaoUi';

@Component
export struct AddCardPanel {
  // 只读
  @Prop STATUS_top_card_add_is_open: boolean;
  @Prop DESIGN_font_color: string;
  @Prop DESIGN_block_background_color: string;

  // 本面板会写入的状态：必须双向绑定回页面
  //
  // ADD_name / ADD_description 必须是 @Link 而不是 @Prop：
  // 它们会被传给 JunHaoTextArea，而 JunHaoTextArea 的 UI_text 是 @Link，
  // 其内部 onChange 靠 `this.UI_text = value` 把用户输入写回。
  // 若这里用 @Prop（单向拷贝），写入就停在副本上，页面的 ADD_name 永远是 ""，
  // CARD_add_card() 的 `if (this.ADD_name == "") return false` 会静默返回，
  // 表现为"点确定没反应"。
  @Link ADD_name: string;
  @Link ADD_description: string;
  @Link ADD_length: number;
  @Link ADD_length_description: string;
  @Link ADD_time_limit: number;
  @Link ADD_time_limit_unit_or_description: string;
  @Link ADD_value_target: number;
  @Link ADD_value_target_unit_or_description: string;

  // 建卡动作留在页面（要维护 9 个数组、cardIds 并落盘）
  onAdd: () => void = () => {
  };

  build() {
    Column({ space: 10 }) {
      Text($r("app.string.Settings_block_Add"))
        .fontSize(25)
        .fontColor(this.DESIGN_font_color)
        .fontWeight(FontWeight.Bold)
        .offset({ y: this.STATUS_top_card_add_is_open ? 0 : 50 })
        .visibility(this.STATUS_top_card_add_is_open ? Visibility.Visible : Visibility.Hidden)
        .animation(animateParam(this.STATUS_top_card_add_is_open ? 50 : 0))

      JunHaoLeftTitle({
        UI_text: $r("app.string.Add_Name_Title"),
        STATUS_show: this.STATUS_top_card_add_is_open,
        DESIGN_font_color: this.DESIGN_font_color,
        UI_delay: 100,
      })

      JunHaoTextArea({
        UI_placeholder: "=￣ω￣=",
        UI_text: this.ADD_name,
        DESIGN_font_color: this.DESIGN_font_color,
        STATUS_show: this.STATUS_top_card_add_is_open,
        UI_area_height: 39,
        UI_delay: 150
      })

      JunHaoLeftTitle({
        UI_text: $r("app.string.Add_Description"),
        STATUS_show: this.STATUS_top_card_add_is_open,
        DESIGN_font_color: this.DESIGN_font_color,
        UI_delay: 200,
      })

      JunHaoTextArea({
        UI_placeholder: "(〃￣︶￣)人(￣︶￣〃)",
        UI_text: this.ADD_description,
        DESIGN_font_color: this.DESIGN_font_color,
        STATUS_show: this.STATUS_top_card_add_is_open,
        UI_area_height: 81,
        UI_delay: 250
      })

      JunHaoLeftTitle({
        UI_text: $r("app.string.Add_Length"),
        STATUS_show: this.STATUS_top_card_add_is_open,
        DESIGN_font_color: this.DESIGN_font_color,
        UI_delay: 300,
      })

      Slider({
        style: SliderStyle.InSet,
        min: 200,
        max: 400,
        value: this.ADD_length
      })
        .blockColor(this.DESIGN_block_background_color)
        .selectedColor(this.DESIGN_font_color)
        .offset({ y: this.STATUS_top_card_add_is_open ? 0 : 50 })
        .visibility(this.STATUS_top_card_add_is_open ? Visibility.Visible : Visibility.Hidden)
        .animation(animateParam(this.STATUS_top_card_add_is_open ? 350 : 0))
        .onChange((value: number, _mode: SliderChangeMode) => {
          this.ADD_length = value
          if (value < 270) {
            this.ADD_length_description = "app.string.Add_Length_Notice_Short"
          } else if (value < 330) {
            this.ADD_length_description = "app.string.Add_Length_Notice_Medium"
          } else {
            this.ADD_length_description = "app.string.Add_Length_Notice_Long"
          }
        })

      JunHaoRightExplanation({
        UI_text: $r(this.ADD_length_description),
        STATUS_show: this.STATUS_top_card_add_is_open,
        DESIGN_font_color: this.DESIGN_font_color,
        UI_max_lines: 1,
        UI_delay: 400,
      })

      JunHaoLeftTitle({
        UI_text: $r("app.string.Add_Time_Limit"),
        STATUS_show: this.STATUS_top_card_add_is_open,
        DESIGN_font_color: this.DESIGN_font_color,
        UI_delay: 450,
      })

      Slider({
        style: SliderStyle.InSet,
        min: 1,
        max: 367,
        value: this.ADD_time_limit
      })
        .blockColor(this.DESIGN_block_background_color)
        .selectedColor(this.DESIGN_font_color)
        .offset({ y: this.STATUS_top_card_add_is_open ? 0 : 50 })
        .visibility(this.STATUS_top_card_add_is_open ? Visibility.Visible : Visibility.Hidden)
        .animation(animateParam(this.STATUS_top_card_add_is_open ? 500 : 0))
        .onChange((value: number, _mode: SliderChangeMode) => {
          this.ADD_time_limit = Math.round(value)
          this.ADD_time_limit_unit_or_description = "app.string.Add_Day"
          if (value == 367) {
            this.ADD_time_limit_unit_or_description = "app.string.Add_Day_Unlimited"
          }
        })

      Row() {
        TextInput({ text: String(this.ADD_time_limit) })
          .type(InputType.Number)
          .onChange((value) => {
            if (value == "") {
            } else {
              this.ADD_time_limit = Math.round(Number(value))
              this.ADD_time_limit_unit_or_description = "app.string.Add_Day"
              if (Number(value) >= 367) {
                this.ADD_time_limit_unit_or_description = "app.string.Add_Day_Unlimited"
                this.ADD_time_limit = 367
              }
            }
          })
          .offset({ y: this.STATUS_top_card_add_is_open ? 0 : 50 })
          .animation(animateParam(550))
          .visibility(this.STATUS_top_card_add_is_open && this.ADD_time_limit != 367 ? Visibility.Visible :
          Visibility.Hidden)
          .layoutWeight(1)
          .fontSize(15)
          .fontWeight(FontWeight.Regular)
          .fontColor(this.DESIGN_font_color)

        Text($r(this.ADD_time_limit_unit_or_description))
          .offset({ y: this.STATUS_top_card_add_is_open ? 0 : 50 })
          .visibility(this.STATUS_top_card_add_is_open ? Visibility.Visible : Visibility.Hidden)
          .animation(animateParam(550))
          .fontSize(15)
          .fontColor(this.DESIGN_font_color)
          .fontWeight(FontWeight.Regular)
          .textAlign(TextAlign.End)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      // Select Time Slider Indicator

      JunHaoLeftTitle({
        UI_text: $r("app.string.Add_Target_Value"),
        STATUS_show: this.STATUS_top_card_add_is_open,
        DESIGN_font_color: this.DESIGN_font_color,
        UI_delay: 600,
      })

      Slider({
        style: SliderStyle.InSet,
        min: 1,
        max: 1001,
        value: this.ADD_value_target
      })
        .offset({ y: this.STATUS_top_card_add_is_open ? 0 : 50 })
        .visibility(this.STATUS_top_card_add_is_open ? Visibility.Visible : Visibility.Hidden)
        .animation(animateParam(this.STATUS_top_card_add_is_open ? 650 : 0))
        .onChange((value: number, _mode: SliderChangeMode) => {
          this.ADD_value_target = Math.round(value)
          this.ADD_value_target_unit_or_description = "app.string.Add_Value_Unit_Hour"
          if (value == 1001) {
            this.ADD_value_target_unit_or_description = "app.string.Add_Value_Unlimited"
          }
        })
        .blockColor(this.DESIGN_block_background_color)
        .selectedColor(this.DESIGN_font_color)

      Row() {
        TextInput({ text: String(this.ADD_value_target) })
          .type(InputType.Number)
          .onChange((value) => {
            if (value == "") {
            } else {
              this.ADD_value_target = Math.round(Number(value))
              this.ADD_value_target_unit_or_description = "app.string.Add_Value_Unit_Hour"
              if (Number(value) >= 1001) {
                this.ADD_value_target_unit_or_description = "app.string.Add_Value_Unlimited"
                this.ADD_value_target = 1001
              }
            }
          })
          .offset({ y: this.STATUS_top_card_add_is_open ? 0 : 50 })
          .animation(animateParam(700))
          .visibility(this.STATUS_top_card_add_is_open && this.ADD_value_target != 1001 ? Visibility.Visible :
          Visibility.Hidden)
          .fontSize(15)
          .fontWeight(FontWeight.Regular)
          .fontColor(this.DESIGN_font_color)
          .layoutWeight(1)

        Text($r(this.ADD_value_target_unit_or_description))
          .offset({ y: this.STATUS_top_card_add_is_open ? 0 : 50 })
          .visibility(this.STATUS_top_card_add_is_open ? Visibility.Visible : Visibility.Hidden)
          .animation(animateParam(750))
          .fontSize(15)
          .fontColor(this.DESIGN_font_color)
          .fontWeight(FontWeight.Regular)
          .textAlign(TextAlign.End)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      // Select Value Indicator

      Button() {
        Text($r("app.string.General_OK"))
          .fontSize(15)
          .fontColor(this.DESIGN_block_background_color)
          .fontWeight(FontWeight.Bolder)
          .animation(animateParam(0))
      }
      .offset({ y: this.STATUS_top_card_add_is_open ? 0 : 50 })
      .visibility(this.STATUS_top_card_add_is_open ? Visibility.Visible : Visibility.Hidden)
      .animation(animateParam(this.STATUS_top_card_add_is_open ? 400 : 0))
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .width("100%")
      .padding(5)
      .backgroundColor(this.DESIGN_font_color)
      .onClick(() => {
        // 建卡（维护 9 个数组 + cardIds + 落盘）留给页面
        this.onAdd()
      })
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 20, right: 20 })
    .position({ y: 165 })
    .visibility(this.STATUS_top_card_add_is_open ? Visibility.Visible : Visibility.None)
    .animation(animateParam(0))
  }
}
