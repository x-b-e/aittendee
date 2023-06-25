import Component from '@glimmer/component';
import didInsert from '@ember/render-modifiers/modifiers/did-insert';
import didUpdate from '@ember/render-modifiers/modifiers/did-update';
import { action } from '@ember/object';
import * as D3 from 'd3';
import cloud from 'd3-cloud';
import { scaleLinear } from 'd3';

export default class WordCloud extends Component {
  @action
  createWordCloud(element) {
    D3.select(element).select("svg").remove();
    const data = this.args.terms;
    if (!data) return;
    const words = data.map((d) => ({ text: d.term, size: d.count }));
    const maxCount = Math.max(...words.map((d) => d.size));
    const fontSizeScale = scaleLinear().domain([0, maxCount]).range([14, 36]);

    const layout = cloud()
      .size([500, 500])
      .words(words)
      .padding(5)
      .rotate(() => (~~(Math.random() * 6) - 3) * 30)
      .fontSize((d) =>fontSizeScale(d.size))
      .on("end", draw);

    layout.start();

    function draw(words) {
      D3.select(element)
        .append("svg")
        .attr("width", layout.size()[0])
        .attr("height", layout.size()[1])
        .append("g")
        .attr("transform", "translate(" + layout.size()[0] / 2 + "," + layout.size()[1] / 2 + ")")
        .selectAll("text")
        .data(words)
        .enter().append("text")
        .style("font-size", (d) => d.size + "px")
        .style("fill", "#000")
        .attr("text-anchor", "middle")
        .attr("transform", (d) => "translate(" + [d.x, d.y] + ")rotate(" + d.rotate + ")")
        .text((d) => d.text);
    }
  }

  <template>
    <div
      class="bg-blue-200"
      {{didInsert this.createWordCloud}}
      {{didUpdate this.createWordCloud @terms}}
    >
    </div>
  </template>
}