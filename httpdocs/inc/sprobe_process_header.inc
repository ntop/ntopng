<a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a>

<div id="chart"></div>

<style>

.link {
  fill: none;
  stroke: #666;
  stroke-width: 1.5px;
}

.link.proc2host {
  stroke-dasharray: 0,2 1;
}

circle {
  fill: #ccc;
  stroke: #333;
  stroke-width: 1.5px;
}

text {
  font: 10px sans-serif;
  pointer-events: none;
  text-shadow: 0 1px 0 #fff, 1px 0 0 #fff, 0 -1px 0 #fff, -1px 0 0 #fff;
}

</style>


<script>

var links; // a global
var nodes = {};

