import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockGoogleAuthenticatedSession } from "../../helpers/mock-api.js";

async function getBox(page) {
  const canvas = page.locator("canvas");
  await expect(canvas).toBeVisible();
  const box = await canvas.boundingBox();
  if (!box) throw new Error("Canvas bounding box unavailable");
  return box;
}

async function drawLine(page, box) {
  await page.mouse.move(box.x + box.width * 0.2, box.y + box.height * 0.3);
  await page.mouse.down();
  await page.mouse.move(box.x + box.width * 0.8, box.y + box.height * 0.7, { steps: 15 });
  await page.mouse.up();
}

test("digital_drawing_object_produced_upon_export", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "digital_drawing_object_produced_upon_export",
    testTitle: testInfo.title,
  });

  let uploadedContentType = null;
  let uploadedByteLength = 0;

  await recorder.step("mock authenticated session and inspect upload payload", async () => {
    await mockGoogleAuthenticatedSession(page);
    await page.route(/^https?:\/\/[^/]+\/api\/upload(?:\?.*)?$/, async (route) => {
      const request = route.request();
      expect(request.method()).toBe("POST");
      const postDataBuffer = request.postDataBuffer();
      uploadedByteLength = postDataBuffer ? postDataBuffer.length : 0;
      uploadedContentType = request.headers()["content-type"] || request.headers()["Content-Type"] || "";
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ ok: true, pathname: "drawings/exported.jpg" }),
      });
    });
  });

  await recorder.step("open draw page and create a stroke", async () => {
    await page.goto("/draw");
    const box = await getBox(page);
    await drawLine(page, box);
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeEnabled();
  });

  await recorder.step("trigger drawing export via share action", async () => {
    await page.getByRole("button", { name: "Share my drawing" }).click();
  });

  await recorder.step("assert non-empty upload object was produced", async () => {
    expect(uploadedContentType).toContain("multipart/form-data");
    expect(uploadedByteLength).toBeGreaterThan(1000);
    await expect(page.getByText("Drawing shared!")).toBeVisible();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:digital_drawing_object_produced_upon_export");
  await recorder.save(testInfo);
});
