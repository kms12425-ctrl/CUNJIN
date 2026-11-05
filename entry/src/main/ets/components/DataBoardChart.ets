/**
 * 寸进 · CUNJIN —— 数据看板：每日打卡热力网格 + 跳到今天
 *
 * 从 pages/Index.ets 原样搬出，未改动布局、尺寸、颜色、动效参数或文案。
 */

@Component
export struct JunHaoDataBoard {
  @Prop DATA_list_of_data: number[] = []
  @Prop DATA_reference_value: number = 1
  @Prop DATA_first_day_stamp: number = 0
  @Prop DATA_today_index: number = 0
  @Prop DESIGN_block_color: string = "#FFFFFF"
  @Prop DESIGN_button_text_color: string = "#000000"
  @Prop ENVIRONMENT_screen_width: number
  @Prop STATUS_current_expand: number
  @Link UI_chosen_block_index: number
  grid_scroller: Scroller = new Scroller()

  build() {
    Column() {
      Row() {
        Text($r("app.string.UI_Days_In_A_Week"))
          .height('100%')
          .lineHeight(29)
          .margin({ right: 10 })
          .textAlign(TextAlign.End)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.DESIGN_block_color)

        Grid(this.grid_scroller) {
          ForEach(this.DATA_days_bias_list(), (_content: string, _key: number) => {
            GridItem() {
              Text()
                .width('100%')
                .height('100%')
                .opacity(0)
            }
            .width(26)
            .onClick(() => {
            })

            // Fill at the front so that the Blocks always start from Sunday
          })

          ForEach(this.STATUS_current_expand == -1 ? [] : this.DATA_list_of_data, (_content: string, key: number) => {
            GridItem() {
              Text()// key.toString()
                .width('100%')
                .height('100%')
                .textAlign(TextAlign.Center)
                .backgroundColor(this.DESIGN_block_color)
                .opacity(
                  this.DESIGN_opacity_of_value(key)
                )
                .borderRadius(key == this.UI_chosen_block_index ? 4 : 6)
            }
            .borderRadius(6)
            .border({
              color: this.DESIGN_block_color,
              width: key == this.UI_chosen_block_index ? 2 : 0
            })
            .width(26)
            .onClick(() => {
              this.UI_chosen_block_index = key
            })
            .clickEffect({ level: ClickEffectLevel.LIGHT })
          })
        }
        .edgeEffect(EdgeEffect.Spring)
        .alignRules({
          top: { anchor: "__container__", align: VerticalAlign.Top },
          left: { anchor: "__container__", align: HorizontalAlign.Start }
        })
        .rowsTemplate("1fr 1fr 1fr 1fr 1fr 1fr 1fr")
        .columnsGap(3)
        .rowsGap(3)
        .height(200)
        .layoutWeight(1)
      }
      .height(200)
      .margin({ bottom: 15 })

      Button() {
        Text($r("app.string.Data_Board_Jump_To_Today"))
          .fontSize(15)
          .fontColor(this.DESIGN_button_text_color)
          .fontWeight(FontWeight.Bolder)
      }
      .width("100%")
      .padding(5)
      .backgroundColor(this.DESIGN_block_color)
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .onClick(() => {
        if (this.DATA_today_index >= 0) {
          this.UI_chosen_block_index = this.DATA_today_index
          this.grid_scroller.scrollToIndex(this.DATA_today_index, true)
        } else {
          console.log("DATA BOARD: SCROLL TO TODAY FAILED DUE TO TIME REVERSION (what?")
        }
      })
    }
  }

  DESIGN_opacity_of_value(key: number) {

    let value = this.DATA_list_of_data == null ? 1 : this.DATA_list_of_data[key]
    let reference = this.DATA_reference_value
    let done_rate = Math.min(value / reference, 1)
    if (done_rate < 0.1) {
      return 0.1
    }
    if (done_rate < 0.3) {
      return 0.3
    }
    if (done_rate < 0.6) {
      return 0.6
    }
    if (done_rate < 0.8) {
      return 0.8
    }
    return done_rate
  }

  DATA_days_bias_list() {
    let first_day = new Date(this.DATA_first_day_stamp).getDay()
    let empty_list: number[] = []
    for (let index = 0; index < first_day; index++) {
      empty_list.push(0)
    }
    return empty_list
  }
}
