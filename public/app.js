jQuery(() => {
  console.log('hello world');
});

// images =[]
// currentIndex = 0

// async function getImages(projectName) {
//   const response = await fetch('/get/frames', {
//     method: 'POST',
//     headers: { 'PROJECT_NAME': projectName },
//   });

//   const frameArray = JSON.parse(await response.json());
//   let arraySize = Math.min(frameArray.length, 5);
  
//   images = []
//   for (let i = 0; i < arraySize; i++) {
//     images.push(frameArray.at(Math.floor(Math.random() * frameArray.length)))
//   }

//   console.log(images)
//   return images
// }

// function flashImages(element) {
//   currentIndex = (currentIndex + 1) % images.length;
//   element.setAttribute('title', `<img class="imageTooltip" src="/pun/sys/dashboard/files/fs${images[currentIndex]}" class="img-fluid" alt="No Frames Rendered :(">`)
// }

// async function startImageFlash(project) {
//   await getImages(projectText.textContent);
//   (setInterval(() => flashImages(linkElement), 500))
// }

// const linkElement = document.getElementById('imagePreview');
// const projectText = document.getElementById('projectName');

// linkElement.addEventListener('hidden.bs.tooltip', async function () {
//   startImageFlash()
// })