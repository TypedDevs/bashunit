<template>
  <div class="product-hunt-banner__container">
    <a
      href="https://www.producthunt.com/posts/bashunit?utm_source=badge-featured&utm_medium=badge&utm_souce=badge-bashunit"
      target="_blank"
      rel="noreferrer"
      title="bashunit - Product Hunt"
    >
      <img
        class="product-hunt-banner__logo--light"
        src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=417750&theme=light"
        alt=""
      />
      <img
        class="product-hunt-banner__logo--dark"
        src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=417750&theme=dark"
        alt=""
      />
    </a>
  </div>
</template>

<script>
export default {}
</script>

<style>
.product-hunt-banner__container {
  text-align: center;
  margin-top: 4rem;
}

.product-hunt-banner__logo--light{
    display: inline-block;
}

.product-hunt-banner__logo--dark{
    display: none;
}

.dark .product-hunt-banner__logo--light{
    display: none;
}

.dark .product-hunt-banner__logo--dark{
    display: inline-block;
}
</style>
