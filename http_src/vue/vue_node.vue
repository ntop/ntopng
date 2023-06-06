<!-- (C) 2022 - ntop.org     -->
<script>
import { h, ref } from 'vue';

export default {
    props: ['content'],
    render() {
	return h(this.$props.content);
    }
};
</script>
