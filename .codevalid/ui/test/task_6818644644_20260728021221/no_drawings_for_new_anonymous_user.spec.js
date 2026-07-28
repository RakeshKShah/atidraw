import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockAnonymousOnlySession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";
import {
  emptyDrawingsResponse,
} from "../../mock/mock-data.js";

test("New anonymous user sees empty drawing list initially", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "no_drawings_for_new_anonymous_user",
    testTitle: testInfo.title,
  });

  await recorder.step("Mock brand-new anonymous session with empty drawings response");
  await mockAnonymousOnlySession(page);
  await mockDrawingsList(page, emptyDrawingsResponse);

  await recorder.step("Open index page without signing in");
  await page.goto("/");

  await recorder.step("Assert no drawings are rendered for a new anonymous user");
  await expect(page.getByRole("img")).toHaveCount(0);
  await expect(page.getByText("Anonymous User")).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:no_drawings_for_new_anonymous_user");
  await recorder.save(testInfo);
});
