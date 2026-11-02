/**
 * 寸进 · CUNJIN —— 单张任务卡片的主体 UI（水波纹卡片、进度、展开动效）
 *
 * 从 pages/Index.ets 原样搬出，未改动布局、尺寸、颜色、动效参数或文案。
 */

@Component
export struct JunHaoBlock {
  @Prop ENVIRONMENT_screen_width: number;
  @Prop ENVIRONMENT_screen_height: number;
  @Prop ENVIRONMENT_current_timestamp: number;
  @State ENVIRONMENT_expanded_width: number = Math.min(500, this.ENVIRONMENT_screen_width - 40)
  @State ENVIRONMENT_waterFlow_column_count: number = 0
  @Link STATUS_card_expanding: number;
  @Link STATUS_last_expanded: number;
  @Prop DESIGN_use_backdrop: boolean;
  @Prop DESIGN_color_scheme: string[];
  @Prop DESIGN_blur_radius: number = 25;
  @Prop DESIGN_font_color: string;
  @State DESIGN_block_color: string = this.DESIGN_color_scheme[4];
  @State UI_y_offset: number = 50;
  @State UI_block_opacity: number = 0;
  @State UI_timeout: number = 0;
  @State UI_card_pressed: boolean = false
  @Link DETAILS_remaining_days: number;
  @Link DETAILS_card_slogan: string;
  @Link DETAILS_Edit_Length_Description: string;
  @Link DETAILS_Edit_name_edit: string;
  @Link DETAILS_Edit_description_edit: string;
  @Link DETAILS_Edit_Length: number;
  @Prop index: number;
  @Prop name: string;
  @Prop desc: string;
  @Prop card_length: number;
  @Prop time_limit: number;
  @Prop target: number;
  @Prop done: number;
  @Prop start: number;
  @Prop end: number;
  // 已归档：卡片仍然显示（不隐藏、不改顺序），只是半透明以示区分
  @Prop archived: boolean;
  // 「设置 - 隐藏已归档」开启且本卡已归档时为 true：用 visibility 隐藏，
  // 不用 filter/条件渲染，保证 ForEach 的下标与卡片数组下标始终一一对应。
  @Prop hide_by_archive: boolean;

  build() {
    FlowItem() {
      RelativeContainer() {
        Column() {
          Text(this.name)
            .fontSize(25)
            .fontColor(this.DESIGN_font_color)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: 6 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }) // BIG TITLE

          // 说明：早期这里有一个 `if (archived) { Text('已归档') }` 的标记。
          // 归档后卡片会立刻隐藏，这个标记永远看不到；而且条件节点会让卡片高度
          // 比别的卡片多出约 35px，表现为"某张卡下面间距更宽"。已移除。
          // 归档的视觉区分保留在下方：虚线边框 + 半透明（都不影响布局高度）。

          Row() {
            Text(this.done == undefined ? "" : this.done.toFixed(2))
              .fontSize(50)
              .fontColor(this.DESIGN_font_color)
              .fontWeight(FontWeight.Bold)
            Text("／" + (this.target == 1001 ? " ∞ " : String(this.target)))
              .fontSize(16)
              .fontColor(this.DESIGN_font_color)
            Text($r('app.string.Add_Value_Unit_Hour')).fontSize(16).fontColor(this.DESIGN_font_color)
          }.alignItems(VerticalAlign.Bottom).margin({ bottom: 14 }).width("100%")

          // BIG DIGITS

          Row() {
            Text($r('app.string.Card_Days_Total')).fontSize(14).fontColor(this.DESIGN_font_color)
            Text((this.time_limit == 367 ? " ∞ " : String(this.time_limit)))
              .fontSize(14)
              .fontColor(this.DESIGN_font_color)
              .fontWeight(FontWeight.Bold)
            Text($r('app.string.Card_Days_Unit_Day')).fontSize(14).fontColor(this.DESIGN_font_color)
          }.width("100%")

          // TOTAL DAYS

          Row() {
            Text($r("app.string.Card_Days_Remaining")).fontSize(14).fontColor(this.DESIGN_font_color)
            Text(this.time_limit == 367 ? " ∞ " : this.getRemainingDays().toFixed(1))
              .fontSize(14)
              .fontColor(this.DESIGN_font_color)
              .fontWeight(FontWeight.Bold)
            Text($r('app.string.Card_Days_Unit_Day')).fontSize(14).fontColor(this.DESIGN_font_color)
          }.width("100%")

          // REMAINING DAYS

        }
        .brightness(this.UI_card_pressed ? 0.94 : 1)
        .width("100%")

        .animation({ duration: 300, curve: Curve.ExtremeDeceleration })
        .alignItems(HorizontalAlign.Start)
        .borderRadius(16)
        .backgroundEffect({
          radius: this.DESIGN_use_backdrop ? this.DESIGN_blur_radius : 0,
          color: this.DESIGN_use_backdrop ? this.DESIGN_color_scheme[4] : this.DESIGN_color_scheme[5]
        })
        .backgroundColor(this.DESIGN_use_backdrop ? "#00000000" : this.DESIGN_color_scheme[5])
        .padding(20)
        .border({
          width: 1,
          color: "#4d7a7a7a",
          // 已归档：虚线边框（与半透明、标题删除线共同构成视觉标记）
          style: this.archived ? BorderStyle.Dashed : BorderStyle.Solid
        })
        .height("100%")
        .offset({ y: (this.STATUS_card_expanding == this.index) ? 200 : 0 })
        .opacity((this.STATUS_card_expanding == this.index) ? 0 : 1)
        .animation({ duration: 400, curve: Curve.ExtremeDeceleration })

        // CONTENTS
      }
      .padding(this.UI_card_pressed ? 5 : 0)
      .width("100%")
      .height("100%")
      .animation({ duration: 300, curve: Curve.ExtremeDeceleration })
    }
    .offset({ y: this.UI_y_offset })
    // 归档只在入场不透明度上乘 0.45：保留原有淡入动画与"展开时透明"的行为
    .opacity(this.archived ? this.UI_block_opacity * 0.45 : this.UI_block_opacity)
    // 「隐藏已归档」用 visibility 而非条件渲染：卡片仍占 ForEach 的一个位置，
    // 因此卡片下标不会错位（STATUS_card_expanding 等状态继续有效）
    .visibility(this.hide_by_archive ? Visibility.None : Visibility.Visible)
    .animation({
      delay: this.index > this.ENVIRONMENT_waterFlow_column_count * 2.5 ? 200 : this.UI_timeout + 400,
      duration: 300,
      curve: Curve.ExtremeDeceleration
    })

    .height(this.card_length)
    .width("100%")
    .animation({ duration: 300, curve: Curve.ExtremeDeceleration })

    .onAreaChange(() => {
      this.UI_y_offset = 0
      this.UI_block_opacity = 100
      this.ENVIRONMENT_expanded_width = Math.min(500, this.ENVIRONMENT_screen_width - 40)
    })
    .onTouch((event: TouchEvent) => {
      if (event.type == TouchType.Down) {
        this.UI_card_pressed = true
      } else if (event.type == TouchType.Up) {
        this.UI_card_pressed = false
      }
    })
    .onClick((_event) => { // Expand and Check details
      this.STATUS_card_expanding = this.index
      this.STATUS_last_expanded = this.index
      this.setDetailsInfo()
    })

  }

  getRemainingDays() {
    return Math.max(0, Number(((this.end - this.ENVIRONMENT_current_timestamp) / 86400000).toFixed(4)))
  }

  setDetailsInfo() {
    this.DETAILS_remaining_days = this.getRemainingDays()
    if (this.done > this.target) { // Already finished
      this.DETAILS_card_slogan = "app.string.Card_Progress_Desc_Already_Done"
    } else { // Not finished
      if (this.time_limit == 367) {
        this.DETAILS_card_slogan = "app.string.Card_Progress_Desc_Time_Ad_Astra_Abyssosque" // No time limit
      } else if (this.DETAILS_remaining_days / this.time_limit > 0.6) {
        this.DETAILS_card_slogan = "app.string.Card_Progress_Desc_Time_Sufficient" // Sufficient (>60%)
      } else if (this.DETAILS_remaining_days / this.time_limit > 0.4) {
        this.DETAILS_card_slogan = "app.string.Card_Progress_Desc_Time_OK" // OK (>40%)
      } else if (this.DETAILS_remaining_days > 0) {
        this.DETAILS_card_slogan = "app.string.Card_Progress_Desc_Time_Quick" // QUICK (>0%)
      } else { // Over due
        this.DETAILS_card_slogan = "app.string.Card_Progress_Desc_Over_Due"
      }
    }

    this.DETAILS_Edit_name_edit = this.name
    this.DETAILS_Edit_description_edit = this.desc
    this.DETAILS_Edit_Length = this.card_length

    if (this.card_length < 270) {
      this.DETAILS_Edit_Length_Description = "app.string.Add_Length_Notice_Short" // Card length Short (l<270)
    } else if (this.card_length < 330) {
      this.DETAILS_Edit_Length_Description = "app.string.Add_Length_Notice_Medium" // Card length Medium (l<330)
    } else {
      this.DETAILS_Edit_Length_Description = "app.string.Add_Length_Notice_Long" // Card length Long
    }
  }
}
